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
