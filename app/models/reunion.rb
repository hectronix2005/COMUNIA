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

  enum :estado, { convocada: 0, celebrada: 1, cancelada: 2 }

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

  def acta_publicada? = acta_publicada_at.present?
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
