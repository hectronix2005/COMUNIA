class Rol < ApplicationRecord
  self.table_name = "roles"

  belongs_to :logia, optional: true

  has_many :rol_permisos, dependent: :destroy
  has_many :permisos, through: :rol_permisos
  has_many :users, foreign_key: :rol_ref_id, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: true
  validates :codigo, presence: true, uniqueness: true

  scope :ordenados, -> { order(:nombre) }

  def tiene_permiso?(recurso, accion)
    permisos.exists?(recurso: recurso, accion: accion)
  end

  def es_super_admin?
    codigo == "super_admin"
  end

  def to_s
    nombre
  end
end
