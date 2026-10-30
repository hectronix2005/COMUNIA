class UserPolicy < ApplicationPolicy
  def update?
    return true if user.rol_ref&.es_super_admin?
    return false unless user.tiene_permiso?("roles", "update") && user.logia
    # El nombre y el correo son de toda la cuenta: si es también de otra comunidad, solo el superadmin los cambia.
    record.logia_id == user.logia_id && !record.de_otras_comunidades?(user.logia.organizacion)
  end

  def edit? = update?
end
