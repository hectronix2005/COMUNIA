class CorteConciliacion < ApplicationRecord
  self.table_name = "corte_conciliaciones"

  belongs_to :logia
  belongs_to :creado_por, class_name: "User"
  has_one_attached :archivo

  enum :estado, {
    pendiente:       0,
    procesado:       1,
    con_diferencias: 2,
    error_parser:    3
  }

  FORMATOS_VALIDOS = %w[
    text/csv
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-excel
    application/pdf
    text/plain
  ].freeze

  MAX_ARCHIVO_SIZE = 20.megabytes

  validates :fecha_corte, presence: true
  validates :logia_id,    presence: true
  validates :fecha_corte, uniqueness: { scope: :logia_id,
    message: "ya existe un corte para esta logia en esa fecha" }
  validate  :archivo_presente, on: :create
  validate  :formato_valido,   if: -> { archivo.attached? }
  validate  :tamano_valido,    if: -> { archivo.attached? }

  scope :recientes, -> { order(fecha_corte: :desc) }

  def coincidentes         = resultado["coincidentes"]         || []
  def sin_match            = resultado["sin_match"]            || []
  def inactivos_en_archivo = resultado["inactivos_en_archivo"] || []
  def solo_en_sistema      = resultado["solo_en_sistema"]      || []
  def no_aplica            = resultado["no_aplica"]            || []

  def estado_badge_color
    { "pendiente" => "secondary", "procesado" => "success",
      "con_diferencias" => "warning", "error_parser" => "danger" }[estado] || "secondary"
  end

  def estado_label
    { "pendiente" => "Pendiente", "procesado" => "Conciliado ✓",
      "con_diferencias" => "Con diferencias", "error_parser" => "Error al procesar" }[estado] || estado
  end

  private

  def archivo_presente
    errors.add(:archivo, "es obligatorio") unless archivo.attached?
  end

  def formato_valido
    unless archivo.content_type.in?(FORMATOS_VALIDOS)
      errors.add(:archivo, "debe ser CSV, Excel o PDF")
    end
  end

  def tamano_valido
    if archivo.byte_size > MAX_ARCHIVO_SIZE
      errors.add(:archivo, "no puede superar #{ActiveSupport::NumberHelper.number_to_human_size(MAX_ARCHIVO_SIZE)}")
    end
  end
end
