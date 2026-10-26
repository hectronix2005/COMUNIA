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
      # El superadmin ve los de todas; los demás, solo los de su organización.
      return scope.all if user.rol_ref&.es_super_admin?
      user.logia ? scope.de_organizacion(user.logia.organizacion) : scope.none
    end
  end
end
