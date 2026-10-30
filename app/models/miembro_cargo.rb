class MiembroCargo < ApplicationRecord
  belongs_to :miembro
  belongs_to :cargo
  belongs_to :asignado_por, class_name: "User", optional: true

  validates :desde, presence: true
  validate :hasta_after_desde
  validate :miembro_debe_estar_activo
  validate :cargo_de_su_logia

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

  # Un cargo es de una logia: no se asigna uno de otra (ni de otra comunidad).
  def cargo_de_su_logia
    return unless cargo && miembro
    errors.add(:cargo, "no es de esta logia") unless cargo.logia_id == miembro.logia_id
  end

  def hasta_after_desde
    return unless desde.present? && hasta.present?
    errors.add(:hasta, "debe ser posterior a la fecha de inicio") if hasta < desde
  end
end
