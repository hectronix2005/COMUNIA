# Quien puede editar las fichas de una logia resuelve las solicitudes de acceso a ella.
class SolicitudAccesoPolicy < ApplicationPolicy
  def index?
    user.tiene_permiso?("miembros", "update")
  end

  def show?
    index? && de_su_alcance?
  end

  def aprobar? = show?
  def rechazar? = show?

  # Crear la ficha nueva al aprobar exige además poder crear miembros.
  def crear_ficha?
    show? && user.tiene_permiso?("miembros", "create")
  end

  # Para el código de la logia: `record` es la Logia.
  def renovar_codigo?
    index? && alcanza?(record.id)
  end

  private

  def de_su_alcance? = alcanza?(record.logia_id)

  def alcanza?(logia_id)
    ids = user.logia_ids_accesibles
    ids.nil? || ids.include?(logia_id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.tiene_permiso?("miembros", "update")
      ids = user.logia_ids_accesibles
      ids.nil? ? scope.all : scope.where(logia_id: ids)
    end
  end
end
