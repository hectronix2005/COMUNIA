class CorteConciliacionPolicy < ApplicationPolicy
  def index?   = tiene_permiso?("miembros", "index")
  def show?    = tiene_permiso?("miembros", "index")
  def create?  = tiene_permiso?("miembros", "update")
  def destroy? = tiene_permiso?("miembros", "destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.tiene_permiso?("miembros", "index")
      ids = user.logia_ids_accesibles
      ids.nil? ? scope.all : scope.where(logia_id: ids)
    end
  end
end
