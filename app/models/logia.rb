class Logia < ApplicationRecord
  # ── Jerarquía Tenant → Logia ────────────────────────────────
  belongs_to :tenant, class_name: "Logia", optional: true
  has_many :logias, class_name: "Logia", foreign_key: :tenant_id, dependent: :destroy

  has_many :users, dependent: :nullify
  has_many :miembros, dependent: :destroy
  has_many :conceptos_cobro, dependent: :destroy
  has_many :tarifas, dependent: :destroy
  has_one_attached :logo

  validates :nombre, presence: true
  validates :codigo, presence: true,
            uniqueness: { scope: :tenant_id, message: "ya existe en este tenant" },
            format: { with: /\A[A-Z0-9]+\z/, message: "solo letras mayusculas y numeros" }
  # Slug solo aplica a tenants raíz (sin padre)
  validates :slug, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "solo minúsculas, números y guiones" },
            if: -> { slug.present? }

  before_validation :generar_slug, if: -> { tenant_id.nil? && slug.blank? && nombre.present? }

  scope :ordenadas,      -> { order(:nombre) }
  scope :tenants_raiz,   -> { where(tenant_id: nil) }
  scope :por_subdominio, ->(sub) { find_by(slug: sub) }

  # ── Branding helpers ──────────────────────────────────────────
  def nombre_display  = nombre_app.presence || nombre
  def icono_display   = icono.presence || "🏛️"
  def lema_display    = lema.presence || ""
  def color_display   = color_primario.presence || "#1B2A4A"

  def t_miembro = termino_miembro.presence || "Miembro"
  def t_logia   = termino_logia.presence   || "Logia"
  def t_cobro   = termino_cobro.presence   || "Cobro"

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
