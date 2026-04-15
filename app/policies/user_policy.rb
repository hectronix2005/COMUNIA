class UserPolicy < ApplicationPolicy
  def update?
    return true if user.rol_ref&.es_super_admin?
    return false unless user.tiene_permiso?("roles", "update")
    record.logia_id == user.logia_id
  end

  def edit? = update?
end
