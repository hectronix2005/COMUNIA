class RolPermisosController < ApplicationController
  before_action :set_rol

  def create
    authorize @rol, :gestionar_permisos?, policy_class: RolPolicy
    permiso = Permiso.find(params[:permiso_id])

    @rol.permisos << permiso unless @rol.permisos.include?(permiso)

    respond_to do |format|
      format.html { redirect_to @rol, notice: "Permiso agregado." }
      format.turbo_stream do
        @permisos_por_recurso = Permiso.por_recurso.group_by(&:recurso)
        @permisos_asignados = @rol.permiso_ids
        render turbo_stream: turbo_stream.replace("permisos-matrix", partial: "roles/permisos_matrix",
          locals: { rol: @rol, permisos_por_recurso: @permisos_por_recurso, permisos_asignados: @permisos_asignados })
      end
    end
  end

  def destroy
    authorize @rol, :gestionar_permisos?, policy_class: RolPolicy
    permiso = Permiso.find(params[:id])

    @rol.permisos.delete(permiso)

    respond_to do |format|
      format.html { redirect_to @rol, notice: "Permiso removido." }
      format.turbo_stream do
        @permisos_por_recurso = Permiso.por_recurso.group_by(&:recurso)
        @permisos_asignados = @rol.permiso_ids
        render turbo_stream: turbo_stream.replace("permisos-matrix", partial: "roles/permisos_matrix",
          locals: { rol: @rol, permisos_por_recurso: @permisos_por_recurso, permisos_asignados: @permisos_asignados })
      end
    end
  end

  private

  def set_rol
    @rol = Rol.find(params[:role_id])
  end
end
