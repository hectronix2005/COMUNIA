class RolPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("roles", "index")
  end

  def show?
    tiene_permiso?("roles", "show")
  end

  def create?
    tiene_permiso?("roles", "create")
  end

  def update?
    tiene_permiso?("roles", "update") && del_usuario?
  end

  def destroy?
    tiene_permiso?("roles", "destroy") && !record.es_sistema? && del_usuario?
  end

  def gestionar_permisos?
    tiene_permiso?("roles", "gestionar_permisos") && del_usuario?
  end

  private

  # Los roles compartidos (sin logia) valen para todas las organizaciones: solo los cambia el superadmin.
  def del_usuario?
    user.rol_ref&.es_super_admin? || (record.logia_id.present? && record.logia_id == user.logia_id)
  end

  public

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.tiene_permiso?("roles", "index")

      if user.rol_ref&.es_super_admin?
        scope.all
      else
        # Tenant admin: system roles + roles of their own logia
        scope.where(logia_id: [nil, user.logia_id])
      end
    end
  end
end
