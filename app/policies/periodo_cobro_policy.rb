class PeriodoCobroPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("periodos", "index")
  end

  def show?
    tiene_permiso?("periodos", "show")
  end

  def create?
    tiene_permiso?("periodos", "create")
  end

  def update?
    tiene_permiso?("periodos", "update")
  end

  def destroy?
    tiene_permiso?("periodos", "destroy") && record.cobros.empty?
  end

  def generar_cobros?
    tiene_permiso?("periodos", "generar_cobros")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
