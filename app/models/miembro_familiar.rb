class MiembroFamiliar < ApplicationRecord
  self.table_name = "miembro_familiares"

  PARENTESCOS = %w[Esposa Esposo Hijo Hija Padre Madre Hermano Hermana Otro].freeze

  belongs_to :miembro

  validates :nombre_completo, presence: true, length: { maximum: 150 }
  validates :parentesco,      presence: true, inclusion: { in: PARENTESCOS }

  scope :con_cumpleanos, -> { where.not(fecha_nacimiento: nil) }

  def cumpleanos_este_anio
    return nil unless fecha_nacimiento
    fecha_nacimiento.change(year: Date.current.year)
  rescue Date::Error
    nil
  end

  def cumpleanos_proximo?
    return false unless fecha_nacimiento
    hoy = Date.current
    cumple = cumpleanos_este_anio
    return false unless cumple
    cumple = cumple.change(year: hoy.year + 1) if cumple < hoy
    (cumple - hoy).to_i.between?(0, 30)
  end
end
