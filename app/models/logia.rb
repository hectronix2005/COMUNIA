class Logia < ApplicationRecord
  include AttachmentValidations

  # ── Jerarquía Tenant → Logia ────────────────────────────────
  belongs_to :tenant, class_name: "Logia", optional: true
  has_many :logias, class_name: "Logia", foreign_key: :tenant_id, dependent: :destroy
  # Tipo de comunidad (Club, Barrio, Masonería…): solo en la raíz; sus grupos la heredan.
  belongs_to :categoria, optional: true

  has_many :users, dependent: :nullify
  has_many :pertenencias, dependent: :destroy
  has_many :pertenencias_de_la_organizacion, class_name: "Pertenencia", foreign_key: :organizacion_id, dependent: :destroy
  has_many :miembros, dependent: :destroy
  has_many :conceptos_cobro, dependent: :destroy
  has_many :tarifas, dependent: :destroy
  has_many :solicitudes_acceso, class_name: "SolicitudAcceso", dependent: :destroy
  has_one_attached :logo
  validates_attachment :logo, types: :image, max: 5.megabytes

  validates :nombre, presence: true
  # El color va dentro del CSS de la página (cabecera, logo): solo un hexadecimal, nada que cierre la regla.
  validates :color_primario, format: { with: /\A#\h{6}\z/, message: "debe ser un color como #0D3436" }, allow_blank: true
  # Dos niveles, organización y logias: el alcance (logia_ids_accesibles, la organización de la URL) no
  # ve más abajo. Solo al cambiar el padre, para que lo ya guardado se pueda seguir editando.
  validate if: :will_save_change_to_tenant_id? do
    errors.add(:tenant, "debe ser una organización, no otra logia") if tenant&.tenant_id
    errors.add(:tenant, "no se puede asignar: esta logia ya tiene logias propias") if tenant && logias.exists?
    errors.add(:tenant, "no puede ser la propia logia") if tenant_id && tenant_id == id
  end
  validate { errors.add(:categoria, "se asigna a la comunidad, no a uno de sus grupos") if categoria_id && tenant_id }
  validates :codigo, presence: true,
            uniqueness: { scope: :tenant_id, message: "ya existe en este tenant" },
            format: { with: /\A[A-Z0-9]+\z/, message: "solo letras mayusculas y numeros" }
  # Slug solo aplica a tenants raíz (sin padre)
  validates :slug, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "solo minúsculas, números y guiones" },
            if: -> { slug.present? }

  before_validation :generar_slug, if: -> { tenant_id.nil? && slug.blank? && nombre.present? }

  scope :ordenadas,      -> { order(:nombre) }
  # Sin la comunidad de demostración del modo invitado (Demo).
  scope :reales,         -> { where(demo: false) }
  # La organización a la que pertenece: ella misma si es raíz.
  def organizacion = tenant || self
  # Ids de la organización y sus logias.
  def ids_de_la_organizacion = [organizacion.id, *organizacion.logias.ids]

  scope :tenants_raiz,   -> { where(tenant_id: nil) }
  scope :por_subdominio, ->(sub) { find_by(slug: sub) }

  # ── Código para pedir acceso ─────────────────────────────────
  # Lo comparten los administradores para que alguien pida entrar (PedirAccesoController). Seis letras y
  # números sin los que se confunden (0/O, 1/I/L, 2/Z, 5/S, 8/B); cambiarlo anula el anterior.
  ALFABETO_ACCESO = "ACDEFGHJKMNPQRTUVWXY34679".chars.freeze

  def self.por_codigo_acceso(texto)
    codigo = texto.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    find_by(codigo_acceso: codigo) if codigo.length == 6
  end

  def renovar_codigo_acceso!
    update_column(:codigo_acceso, Array.new(6) { ALFABETO_ACCESO.sample(random: SecureRandom) }.join)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def codigo_acceso_legible = codigo_acceso && "#{codigo_acceso[0, 3]}-#{codigo_acceso[3, 3]}"

  # ── Branding helpers ──────────────────────────────────────────
  def nombre_display  = nombre_app.presence || nombre
  def icono_display   = icono.presence || "🏛️"
  def lema_display    = lema.presence || ""
  def color_display   = color_primario.to_s.match?(/\A#\h{6}\z/) ? color_primario : "#0D3436"

  # ── Palabras y módulos ────────────────────────────────────────
  # Cada palabra sale de la propia logia, si no de su comunidad, si no de la categoría de la comunidad, y si
  # no de aquí. Las logias solo guardan miembro, logia y cobro; el resto viene de la categoría.
  TERMINOS_POR_DEFECTO = {
    miembro: "Miembro", logia: "Grupo", cobro: "Cobro",
    reunion: "Reunión", ayuda: "Fondo de ayuda", documentos: "Documentos"
  }.freeze

  def termino(clave)
    [self, organizacion, organizacion.categoria].compact.uniq
      .map { _1.try(:"termino_#{clave}") }.find(&:present?) || TERMINOS_POR_DEFECTO.fetch(clave)
  end

  def t_miembro    = termino(:miembro)
  def t_logia      = termino(:logia)
  def t_cobro      = termino(:cobro)
  def t_reunion    = termino(:reunion)
  def t_ayuda      = termino(:ayuda)
  def t_documentos = termino(:documentos)
  def t_reuniones  = Logia.plural(t_reunion)

  # Plural en español (pluralize es el inglés): «Reunión» → «Reuniones», «Tenida» → «Tenidas».
  def self.plural(palabra)
    case palabra
    when /[aeiouáéó]\z/i then "#{palabra}s"
    when /z\z/i then "#{palabra[0..-2]}ces"
    else "#{palabra.unicode_normalize(:nfd).sub(/\p{Mn}(?=\p{L}*\z)/, '').unicode_normalize(:nfc)}es"
    end
  end

  # Una comunidad sin categoría tiene todos los módulos.
  def modulo?(clave)
    categoria = organizacion.categoria
    categoria.nil? || categoria.modulo?(clave)
  end

  # «Club · Mercedes Benz · SUV»: categoría, comunidad y, si es un grupo, su nombre.
  def ruta_comunidad
    [organizacion.categoria&.nombre, organizacion.nombre, (nombre if tenant_id)].compact.join(" · ")
  end

  def siguiente_rc!
    with_lock do
      next_seq = (rc_secuencia_actual || 0) + 1
      update_column(:rc_secuencia_actual, next_seq)
      "RC-#{codigo}-#{Time.current.year}-#{next_seq.to_s.rjust(4, '0')}"
    end
  end

  # Cuota mensual que paga cada miembro (suma de todos los conceptos por miembro)
  def monto_mensual
    activos_count = miembros.activos.count
    return 0 if activos_count.zero?

    complemento = conceptos_cobro.activos.where(tipo: :complemento).first
    return complemento.monto if complemento

    suma_conceptos_base(activos_count)
  end

  # Suma de conceptos NO complemento, expresados por miembro
  def suma_conceptos_base(activos_count = nil)
    activos_count ||= miembros.activos.count
    return 0 if activos_count.zero?

    total = 0
    conceptos_cobro.activos.where.not(tipo: :complemento).each do |c|
      total += c.por_miembro? ? c.monto : (c.monto / activos_count).round(0)
    end
    total
  end

  # Suma de todos los conceptos per cápita excluyendo uno dado
  def suma_conceptos_sin(concepto_excluido)
    activos_count = miembros.activos.count
    return 0 if activos_count.zero?

    total = 0
    conceptos_cobro.activos.where.not(id: concepto_excluido.id).where.not(tipo: :complemento).each do |c|
      total += c.por_miembro? ? c.monto : (c.monto / activos_count).round(0)
    end
    total
  end

  def tiene_conceptos?
    conceptos_cobro.activos.any?
  end

  # Cuántos miembros eran cobrables en una fecha dada
  def miembros_cobrables_count_en(fecha)
    activo_val = Miembro.estados[:activo]
    miembros.where(
      "estado = :a " \
      "OR (estado != :a AND estado_desde IS NOT NULL AND estado_desde > :f) " \
      "OR (estado != :a AND estado_hasta IS NOT NULL AND estado_hasta < :f)",
      a: activo_val, f: fecha
    ).count
  end

  # Cuota mensual calculada para un conteo específico de miembros
  def monto_mensual_para_conteo(conteo)
    return 0 if conteo.zero?
    complemento = conceptos_cobro.activos.where(tipo: :complemento).first
    return complemento.monto if complemento

    total = 0
    conceptos_cobro.activos.where.not(tipo: :complemento).each do |c|
      total += c.por_miembro? ? c.monto : (c.monto / conteo).round(0)
    end
    total
  end

  # Retorna la tarifa vigente para una fecha, o nil
  def tarifa_vigente(fecha = Date.current)
    tarifas.vigente_para(fecha)
  end

  # Monto mensual aplicable para una fecha (tarifa si existe, sino conceptos con conteo correcto)
  def monto_para_fecha(fecha)
    tarifa = tarifa_vigente(fecha)
    return tarifa.monto if tarifa
    conteo = miembros_cobrables_count_en(fecha)
    monto_mensual_para_conteo(conteo)
  end

  private

  def generar_slug
    base = nombre_app.presence || nombre
    self.slug = base.downcase
                    .gsub(/[áàä]/, "a").gsub(/[éèë]/, "e")
                    .gsub(/[íìï]/, "i").gsub(/[óòö]/, "o")
                    .gsub(/[úùü]/, "u").gsub(/ñ/, "n")
                    .gsub(/[^a-z0-9\s]/, "").strip.gsub(/\s+/, "-")
                    .gsub(/-+/, "-").gsub(/\A-|-\z/, "")
  end
end
