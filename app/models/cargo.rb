class Cargo < ApplicationRecord
  belongs_to :logia
  has_many :miembro_cargos, dependent: :destroy
  has_many :miembros, through: :miembro_cargos

  validates :nombre, presence: true, uniqueness: { scope: :logia_id, message: "ya existe en esta logia" }
  validates :logia_id, presence: true

  scope :activos, -> { where(activo: true) }
  scope :ordenados, -> { order(:nombre) }

  PREDEFINIDOS = [
    "Venerable Maestro",
    "Primer Vigilante",
    "Segundo Vigilante",
    "Orador",
    "Secretario",
    "Tesorero",
    "Hospitalario",
    "Maestro de Ceremonias",
    "Experto",
    "Primer Diácono",
    "Segundo Diácono",
    "Guardatemplo"
  ].freeze

  def self.seed_para_logia(logia)
    PREDEFINIDOS.each do |nombre|
      find_or_create_by(nombre: nombre, logia_id: logia.id)
    end
  end
end
