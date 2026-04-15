class LogiaPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("logias", "index")
  end

  def show?
    tiene_permiso?("logias", "show")
  end

  def create?
    tiene_permiso?("logias", "create")
  end

  def update?
    tiene_permiso?("logias", "update")
  end

  def destroy?
    tiene_permiso?("logias", "destroy")
  end

  def gestionar_conceptos?
    tiene_permiso?("logias", "gestionar_conceptos")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.tiene_permiso?("logias", "index")
        if user.scope_propia_logia?
          scope.where(id: user.logia_id)
        else
          scope.all
        end
      else
        scope.none
      end
    end
  end
end
