class MiembroFamiliar < ApplicationRecord
  self.table_name = "miembro_familiares"

  PARENTESCOS = %w[Esposa Esposo Hijo Hija Padre Madre Hermano Hermana Otro].freeze

  belongs_to :miembro

  validates :nombre_completo, presence: true, length: { maximum: 150 }
  validates :parentesco,      presence: true, inclusion: { in: PARENTESCOS }

  scope :con_cumpleanos, -> { where.not(fecha_nacimiento: nil) }

  # Siguiente cumpleaños desde `desde` (incluido). Quien nació un 29 de febrero lo celebra el 28 los
  # años que no son bisiestos; antes esos cumpleaños no salían nunca.
  def proximo_cumpleanos(desde = Date.current)
    return unless fecha_nacimiento
    [desde.year, desde.year + 1].each do |anio|
      mes, dia = fecha_nacimiento.month, fecha_nacimiento.day
      fecha = Date.valid_date?(anio, mes, dia) ? Date.new(anio, mes, dia) : Date.new(anio, 2, 28)
      return fecha if fecha >= desde
    end
  end

  def cumpleanos_este_anio
    return nil unless fecha_nacimiento
    fecha_nacimiento.change(year: Date.current.year)
  rescue Date::Error
    nil
  end

  def cumpleanos_proximo?
    cumple = proximo_cumpleanos or return false
    (cumple - Date.current).to_i <= 30
  end
end
