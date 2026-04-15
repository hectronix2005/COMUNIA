class BibliotecaPlancha < ApplicationRecord
  include AttachmentValidations

  GRADOS = %w[Aprendiz Compañero Maestro].freeze
  GRADO_NIVEL = { "Aprendiz" => 1, "Compañero" => 2, "Maestro" => 3 }.freeze

  belongs_to :logia
  belongs_to :user
  has_one_attached :documento
  validates_attachment :documento, types: :doc, max: 25.megabytes

  validates :titulo, presence: true, length: { maximum: 200 }
  validates :grado,  presence: true, inclusion: { in: GRADOS }

  scope :activas,       -> { where(activo: true) }
  scope :de_logia,      ->(id) { where(logia_id: id) }
  scope :de_grado,      ->(g) { where(grado: g) }
  scope :ordenadas,     -> { order(grado: :asc, created_at: :desc) }

  # Returns planchas visible to a given grado level
  scope :visibles_para, ->(grado) {
    nivel = GRADO_NIVEL[grado].to_i
    grads = GRADOS.select { |g| GRADO_NIVEL[g] <= nivel }
    where(grado: grads)
  }

  def nivel_grado
    GRADO_NIVEL[grado].to_i
  end
end
