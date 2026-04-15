class MiembroEstadoCambio < ApplicationRecord
  include AttachmentValidations

  ESTADO_COLORS = {
    "activo"               => "success",
    "quite"                => "dark",
    "irregular_temporal"   => "warning",
    "irregular_permanente" => "danger"
  }.freeze

  ESTADO_LABELS = {
    "activo"               => "Activo",
    "quite"                => "Quite",
    "irregular_temporal"   => "Irregular Temporal",
    "irregular_permanente" => "Irregular Permanente"
  }.freeze

  belongs_to :miembro
  belongs_to :registrado_por, class_name: "User", optional: true

  has_one_attached :soporte
  validates_attachment :soporte, types: :doc, max: 10.megabytes

  validates :estado, presence: true
  validates :desde,  presence: true
  validate  :hasta_posterior_a_desde
  validate  :soporte_requerido_para_inactividad, on: :create

  TIPOS_VALIDOS_SOPORTE = %w[image/jpeg image/png image/webp application/pdf].freeze
  TAMANIO_MAXIMO_SOPORTE = 10.megabytes

  scope :cronologicos, -> { order(desde: :desc, created_at: :desc) }

  def estado_label
    ESTADO_LABELS[estado] || estado.humanize
  end

  def estado_color
    ESTADO_COLORS[estado] || "secondary"
  end

  private

  def hasta_posterior_a_desde
    return unless desde.present? && hasta.present?
    errors.add(:hasta, "debe ser posterior a la fecha de inicio") if hasta < desde
  end

  def soporte_requerido_para_inactividad
    return if estado == "activo"
    return if soporte.attached?
    errors.add(:soporte, "es obligatorio al registrar un cambio de estado")
  end
end
