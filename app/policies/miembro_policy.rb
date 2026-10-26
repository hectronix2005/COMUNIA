class MiembroPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("miembros", "index")
  end

  def show?
    tiene_permiso?("miembros", "show") || record.user_id == user.id
  end

  def create?
    tiene_permiso?("miembros", "create")
  end

  def update?
    tiene_permiso?("miembros", "update")
  end

  # Generar un enlace de invitación es poder entrar en esa cuenta: solo para miembros rasos (un admin de
  # logia no se apodera así de otro admin ni del superadmin), y nunca para la propia cuenta.
  def invitar?
    return false unless update? && record.user_id != user.id
    destino = record.user
    user.rol_ref&.es_super_admin? || (destino.miembro? && destino.rol_ref&.codigo == "miembro")
  end

  # La página de invitar en bloque; a cada miembro de la lista se le aplica además invitar?.
  def invitar_en_bloque?
    update?
  end

  def destroy?
    tiene_permiso?("miembros", "destroy")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.tiene_permiso?("miembros", "index")
        ids = user.logia_ids_accesibles
        ids.nil? ? scope.all : scope.where(logia_id: ids)
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
