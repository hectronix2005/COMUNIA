# Un acuerdo que sale de una reunión: qué se hará, quién se encarga (un convocado) y para cuándo. Lo ve quien ve la
# reunión; quien se encarga lo tiene en su panel y, mientras no se cumpla, sale en la siguiente convocatoria del
# mismo grupo.
class ReunionAcuerdo < ApplicationRecord
  belongs_to :reunion
  belongs_to :responsable, class_name: "Miembro", optional: true

  MAX_POR_REUNION = 30

  scope :pendientes, -> { where(cumplido_at: nil) }

  validates :texto, presence: true, length: { maximum: 500 }
  validate :responsable_convocado
  validate :tope_por_reunion, on: :create

  def cumplido? = cumplido_at.present?
  def vencido? = !cumplido? && vence_el&.past?

  private

  def responsable_convocado
    return unless reunion && responsable_id
    errors.add(:responsable, "debe ser un convocado") unless reunion.convocados.exists?(id: responsable_id)
  end

  def tope_por_reunion
    return unless reunion && reunion.reunion_acuerdos.count >= MAX_POR_REUNION
    errors.add(:base, "Esta convocatoria ya tiene #{MAX_POR_REUNION} acuerdos.")
  end
end
