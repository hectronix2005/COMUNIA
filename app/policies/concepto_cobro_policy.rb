class ConceptoCobroPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("conceptos", "index")
  end

  def show?
    tiene_permiso?("conceptos", "show")
  end

  def create?
    tiene_permiso?("conceptos", "create")
  end

  def update?
    tiene_permiso?("conceptos", "update")
  end

  def destroy?
    tiene_permiso?("conceptos", "destroy")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
