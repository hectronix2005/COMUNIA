class RolPermiso < ApplicationRecord
  belongs_to :rol
  belongs_to :permiso

  validates :permiso_id, uniqueness: { scope: :rol_id }
end
