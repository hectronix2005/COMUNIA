class ConceptoCobro < ApplicationRecord
  self.table_name = "conceptos_cobros"

  enum :tipo, { por_miembro: 0, por_logia: 1, complemento: 2 }

  belongs_to :logia

  validates :nombre, presence: true
  validates :monto, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :nombre, uniqueness: { scope: :logia_id }

  scope :activos, -> { where(activo: true) }
  scope :ordenados, -> { order(:orden, :nombre) }

  def monto_por_miembro
    case tipo
    when "por_miembro"
      monto
    when "por_logia"
      total_activos = logia.miembros.activos.count
      return 0 if total_activos.zero?
      (monto / total_activos).round(0)
    when "complemento"
      residuo
    end
  end

  # Para complemento: cuota per cápita total - suma de los demás conceptos
  def residuo
    suma_otros = logia.suma_conceptos_sin(self)
    diferencia = monto - suma_otros
    [diferencia, 0].max
  end
end
