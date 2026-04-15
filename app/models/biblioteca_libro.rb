class BibliotecaLibro < ApplicationRecord
  CATEGORIAS = %w[Filosofía Historia Ritual Esotérico Ciencia Arte Literatura Otro].freeze

  belongs_to :logia
  belongs_to :user
  has_one_attached :archivo
  has_many :calificaciones, class_name: "BibliotecaCalificacion",
                            foreign_key: :libro_id, dependent: :destroy

  validates :titulo, presence: true, length: { maximum: 200 }

  scope :activos,   -> { where(activo: true) }
  scope :de_logia,  ->(id) { where(logia_id: id) }
  scope :ordenados, -> { order(created_at: :desc) }
  scope :buscar,    ->(q) {
    where("titulo ILIKE :q OR autor ILIKE :q OR descripcion ILIKE :q", q: "%#{q}%")
  }

  def promedio_calificacion
    calificaciones.average(:puntuacion)&.round(1) || 0
  end

  def total_calificaciones
    calificaciones.count
  end

  def calificacion_de(user)
    calificaciones.find_by(user: user)
  end

  def tiene_archivo?
    archivo.attached? || url_externa.present?
  end
end
