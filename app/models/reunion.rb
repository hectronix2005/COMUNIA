# Reunión de un grupo, o de toda la comunidad si se convoca en la raíz. Se llama según la categoría
# (tenida, encuentro, asamblea). Al convocarla se crea su evento en el calendario: quien confirma ahí, confirma
# aquí. Después se registra quién asistió (quórum) y se publica el acta.
class Reunion < ApplicationRecord
  belongs_to :logia
  belongs_to :user
  belongs_to :calendario_evento, optional: true
  has_many :reunion_asistencias, dependent: :delete_all
  has_many :asistentes, through: :reunion_asistencias, source: :miembro
  has_many :reunion_votaciones, -> { order(:created_at) }, dependent: :destroy
  has_many :reunion_propuestas, -> { order(:created_at) }, dependent: :delete_all

  enum :estado, { convocada: 0, celebrada: 1, cancelada: 2 }

  # Código del QR con el que cada convocado marca su asistencia en la reunión.
  has_secure_token :codigo_asistencia, length: 24, on: :create # al guardar: las copias de una serie no lo heredan

  REPETICIONES = {
    "semanal"   => "Cada semana",
    "quincenal" => "Cada dos semanas",
    "mensual"   => "Cada mes, el mismo día de la semana"
  }.freeze
  MAX_FECHAS = 12
  MAX_DESDE_EVENTOS = 60 # un año de una serie semanal del calendario

  validates :titulo, presence: true, length: { maximum: 200 }
  validates :lugar, length: { maximum: 200 }
  validates :orden_del_dia, :acta, length: { maximum: 20_000 }
  validates :inicio, :fin, presence: true
  validate { errors.add(:fin, "debe ser posterior al inicio") if inicio && fin && fin <= inicio }

  scope :proximas, -> { where(estado: :convocada).where(fin: Time.current..).order(:inicio) }
  scope :pasadas,  -> { where.not(id: proximas.select(:id)).order(inicio: :desc) }

  # Si se convoca con menos de un día, la convocatoria ya hace de recordatorio.
  before_create { self.recordatorio_enviado_at = Time.current if inicio && inicio < 24.hours.from_now }
  after_save :sincronizar_evento
  after_destroy { calendario_evento&.destroy }

  # Se convoca a los miembros activos del grupo; en la raíz, a los de toda la comunidad.
  def logia_ids_convocadas = logia.tenant_id ? [logia_id] : [logia_id, *logia.logias.ids]
  def convocados = Miembro.activos.where(logia_id: logia_ids_convocadas)

  def confirmaciones = calendario_evento ? calendario_evento.evento_confirmaciones : EventoConfirmacion.none
  def respuesta_de(user) = confirmaciones.find_by(user: user)&.estado

  # Quórum: asistentes sobre convocados (en %, redondeado).
  def quorum
    total = convocados.count
    total.zero? ? 0 : (reunion_asistencias.count * 100.0 / total).round
  end

  # Una serie son reuniones independientes (cada una con su evento, confirmación, asistencia y acta) que
  # comparten la marca `serie`. Cancelar «esta y las siguientes» toca solo las convocadas desde esta fecha.
  def otras_de_la_serie = serie ? Reunion.where(serie: serie, logia_id: logia_id).where.not(id: id).order(:inicio) : Reunion.none
  def serie_desde_aqui = serie ? Reunion.where(serie: serie, logia_id: logia_id).convocada.where(inicio: inicio..).order(:inicio) : Reunion.none

  # Inicios de una serie a partir del primero: cada una o dos semanas, o cada mes en el mismo día de la
  # semana (el segundo martes, por ejemplo; si era el quinto, el último del mes).
  def self.fechas_de_serie(inicio, repetir, veces)
    Array.new(veces) do |i|
      case repetir
      when "semanal"   then inicio + i.weeks
      when "quincenal" then inicio + (2 * i).weeks
      when "mensual"   then mismo_dia_de_la_semana(inicio, i)
      end
    end
  end

  def self.mismo_dia_de_la_semana(inicio, meses)
    mes = inicio.to_date.beginning_of_month >> meses
    dia = mes + ((inicio.wday - mes.wday) % 7) + ((inicio.day - 1) / 7 * 7)
    dia -= 7 if dia.month != mes.month
    inicio.change(year: dia.year, month: dia.month, day: dia.day)
  end

  # Un evento del calendario (y sus fechas siguientes, si es de una serie) pasa a ser reunión del grupo: se
  # conservan las respuestas y el evento queda como el de la reunión. No se avisa: ya estaba en el calendario.
  def self.desde_eventos!(eventos, logia:, user:)
    serie = SecureRandom.uuid if eventos.size > 1
    prefijo = /\A#{Regexp.escape(logia.t_reunion)}[\s:]+/i
    transaction do
      CalendarioEvento.separar_de_la_serie!(eventos)
      eventos.map do |evento|
        reunion = create!(logia: logia, user: user, serie: serie, calendario_evento: evento,
                          titulo: evento.titulo.sub(prefijo, "").presence || evento.titulo,
                          inicio: evento.inicio, fin: evento.fin, lugar: evento.ubicacion, orden_del_dia: evento.descripcion)
        # El recordatorio que el evento no mandó sigue pendiente (al crearla con menos de un día se daría por enviado).
        reunion.update_column(:recordatorio_enviado_at, evento.recordatorio_enviado_at)
        reunion
      end
    end
  end

  # Constancia de cada miembro en las reuniones celebradas desde una fecha: a cuántas se le convocó (las de su grupo
  # y las de la raíz, desde que tiene ficha), a cuántas asistió, la última vez que vino y cuántas lleva sin venir.
  Constancia = Data.define(:miembro, :convocadas, :asistidas, :ultima, :faltas_seguidas) do
    def porcentaje = convocadas.zero? ? nil : (asistidas * 100.0 / convocadas).round
  end

  def self.constancia(miembros, desde: 1.year.ago)
    miembros = miembros.includes(:user, :logia).to_a
    raiz = miembros.to_h { [_1.logia_id, _1.logia.tenant_id || _1.logia_id] }
    reuniones = celebrada.where(logia_id: (raiz.keys + raiz.values).uniq, inicio: desde..Time.current).order(:inicio)
                         .pluck(:id, :logia_id, :inicio)
    asistio = ReunionAsistencia.where(reunion_id: reuniones.map(&:first), miembro_id: miembros.map(&:id))
                               .pluck(:reunion_id, :miembro_id).to_set
    miembros.map do |m|
      suyas = reuniones.select { |_, logia_id, inicio| logia_id.in?([m.logia_id, raiz[m.logia_id]]) && inicio >= m.created_at }
      fue = suyas.select { |id, _, _| asistio.include?([id, m.id]) }
      Constancia.new(miembro: m, convocadas: suyas.size, asistidas: fue.size, ultima: fue.last&.last,
                     faltas_seguidas: suyas.reverse.take_while { |id, _, _| !asistio.include?([id, m.id]) }.size)
    end
  end

  def acta_publicada? = acta_publicada_at.present?

  # Los puntos para el orden del día se proponen mientras está convocada y antes de que empiece.
  def admite_propuestas? = convocada? && inicio.future?

  # El QR vale desde una hora antes hasta una hora después.
  def asistencia_abierta? = !cancelada? && (inicio - 1.hour..fin + 1.hour).cover?(Time.current)
  def nombre = "#{logia.t_reunion}: #{titulo}"

  private

  def sincronizar_evento
    datos = { titulo: nombre, inicio: inicio, fin: fin, ubicacion: lugar, descripcion: orden_del_dia, logia: logia }
    if cancelada?
      calendario_evento&.destroy
      update_column(:calendario_evento_id, nil) if calendario_evento_id
    elsif calendario_evento
      calendario_evento.update!(datos)
    else
      evento = CalendarioEvento.create!(datos.merge(user: user, color: logia.organizacion.color_display))
      update_column(:calendario_evento_id, evento.id)
    end
  end
end
