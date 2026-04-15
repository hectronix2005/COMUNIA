class MiembroCargo < ApplicationRecord
  belongs_to :miembro
  belongs_to :cargo
  belongs_to :asignado_por, class_name: "User", optional: true

  validates :desde, presence: true
  validate :hasta_after_desde
  validate :miembro_debe_estar_activo

  scope :vigentes, -> { where(hasta: nil) }
  scope :historicos, -> { where.not(hasta: nil) }
  scope :cronologicos, -> { order(desde: :desc) }

  def vigente?
    hasta.nil?
  end

  private

  def miembro_debe_estar_activo
    return unless miembro.present? && new_record?
    errors.add(:base, "Solo se pueden asignar cargos a miembros activos") unless miembro.activo?
  end

  def hasta_after_desde
    return unless desde.present? && hasta.present?
    errors.add(:hasta, "debe ser posterior a la fecha de inicio") if hasta < desde
  end
end
