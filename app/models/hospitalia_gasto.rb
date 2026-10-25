class HospitaliaGasto < ApplicationRecord
  include AttachmentValidations

  belongs_to :logia
  belongs_to :user
  belongs_to :beneficiario, class_name: "Miembro", foreign_key: :beneficiario_id, optional: true
  has_one_attached :soporte
  validates_attachment :soporte, types: :doc, max: 10.megabytes

  validates :concepto, presence: true, length: { maximum: 200 }
  validates :monto,    presence: true, numericality: { greater_than: 0 }
  validates :fecha,    presence: true
  # El selector solo ofrece miembros de la logia; un id de otra se rechaza (la lista enseñaría su nombre).
  validate { errors.add(:beneficiario, "no es de esta logia") if beneficiario && beneficiario.logia_id != logia_id }

  scope :de_logia,  ->(id) { where(logia_id: id) }
  scope :ordenados, -> { order(fecha: :desc, created_at: :desc) }
  scope :del_anio,  ->(y) { where(fecha: Date.new(y).beginning_of_year..Date.new(y).end_of_year) }
end
