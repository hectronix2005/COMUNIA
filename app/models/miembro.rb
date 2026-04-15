class Miembro < ApplicationRecord
  ESTADOS_NO_COBRABLES = %w[quite irregular_temporal irregular_permanente].freeze

  # Usados en vistas de conciliación para badges de estado
  ESTADO_COLOR = {
    "activo"               => "success",
    "quite"                => "secondary",
    "irregular_temporal"   => "warning",
    "irregular_permanente" => "danger"
  }.freeze

  ESTADO_LABEL = {
    "activo"               => "Activo",
    "quite"                => "Quite",
    "irregular_temporal"   => "Irregular Temporal",
    "irregular_permanente" => "Irregular Permanente"
  }.freeze

  enum :estado, {
    activo:               0,
    quite:                3,
    irregular_temporal:   4,
    irregular_permanente: 5
  }

  belongs_to :user
  belongs_to :logia
  has_many :cobros,         dependent: :destroy
  has_many :estado_cambios, class_name: "MiembroEstadoCambio", dependent: :destroy
  has_many :miembro_cargos, dependent: :destroy
  has_many :cargos, through: :miembro_cargos
  has_many :familiares,     class_name: "MiembroFamiliar", dependent: :destroy

  validates :numero_miembro, presence: true, uniqueness: true
  validates :cedula, presence: true, uniqueness: true
  validates :user_id, uniqueness: true
  validates :estado_desde, presence: true, if: -> { !activo? }
  validates :estado_hasta, comparison: { greater_than_or_equal_to: :estado_desde },
                           if: -> { estado_desde.present? && estado_hasta.present? }

  scope :activos,      -> { where(estado: :activo) }
  scope :por_logia,    ->(logia_id) { where(logia_id: logia_id) }
  # Cobrables en una fecha: activos en esa fecha (ni en período inactivo que la cubra)
  scope :cobrables_en, ->(fecha) {
    where(estado: :activo)
      .or(where.not(estado: :activo).where("estado_desde IS NOT NULL AND estado_desde > ?", fecha))
      .or(where.not(estado: :activo).where("estado_hasta IS NOT NULL AND estado_hasta < ?", fecha))
  }
  # Estado histórico en una fecha usando el historial de cambios.
  # Busca el cambio de estado más reciente cuyo 'desde' sea <= fecha.
  # Si no existe historial previo, asume 'activo' (estado inicial por defecto).
  scope :en_estado_en_fecha, ->(estado_val, fecha) {
    quoted_fecha  = connection.quote(fecha.to_s)
    quoted_estado = connection.quote(estado_val.to_s)
    joins(Arel.sql(
      "LEFT JOIN LATERAL (
        SELECT ec.estado AS estado_historico
        FROM miembro_estado_cambios ec
        WHERE ec.miembro_id = miembros.id AND ec.desde <= #{quoted_fecha}
        ORDER BY ec.desde DESC, ec.created_at DESC
        LIMIT 1
      ) hist ON true"
    )).where(
      "COALESCE(hist.estado_historico,
        CASE miembros.estado
          WHEN 0 THEN 'activo'
          WHEN 3 THEN 'quite'
          WHEN 4 THEN 'irregular_temporal'
          WHEN 5 THEN 'irregular_permanente'
          ELSE 'activo'
        END
      ) = #{quoted_estado}"
    )
  }

  delegate :nombre_completo, :email, to: :user

  # Registra un alias externo (ej: "ABUASSI ESPITIA RICARDO") si aún no existe.
  # Ignora strings vacíos, demasiado largos o que parezcan datos numéricos (OCR errors).
  def agregar_alias(nombre_externo)
    return if nombre_externo.blank?

    normalizado = nombre_externo.strip.upcase
    return if normalizado.length > 150
    return if normalizado.gsub(/\D/, "").length > normalizado.length / 2  # >50% dígitos
    return if aliases.include?(normalizado)

    update_column(:aliases, aliases + [normalizado])
  end

  def nombre_display
    "#{user.nombre_completo} (#{numero_miembro})"
  end

  # ¿Se le puede cobrar cuota en una fecha dada?
  def cobrable_en?(fecha)
    return true if activo?
    # Período inactivo aún no inicia en esa fecha
    return true if estado_desde.present? && estado_desde > fecha
    # Período inactivo ya terminó antes de esa fecha
    return true if estado_hasta.present? && estado_hasta < fecha
    false
  end

  def estado_label
    case estado
    when "activo"               then "Activo"
    when "quite"                then "Quite"
    when "irregular_temporal"   then "Irregular Temporal"
    when "irregular_permanente" then "Irregular Permanente"
    else estado.humanize
    end
  end
end
