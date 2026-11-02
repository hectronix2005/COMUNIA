# Evento abierto a todos los de una sombrilla (una feria, una jornada, una reunión de vecinos).
class SombrillaEvento < ApplicationRecord
  self.table_name = "sombrilla_eventos"
  include ContenidoDeSombrilla

  belongs_to :sombrilla

  validates :titulo, presence: true, length: { maximum: 120 }
  validates :lugar, length: { maximum: 160 }
  validates :descripcion, length: { maximum: 2000 }
  validates :inicio, presence: true

  scope :proximos, -> { where(inicio: 3.hours.ago..).order(:inicio) }

  def sombrilla_de = sombrilla
end
