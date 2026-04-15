class RolesController < ApplicationController
  before_action :set_rol, only: [:show, :edit, :update, :destroy]

  def index
    @roles = policy_scope(Rol).includes(:logia, users: :logia).ordenados
    authorize Rol
  end

  def show
    authorize @rol
    @permisos_por_recurso = Permiso.por_recurso.group_by(&:recurso)
    @permisos_asignados = @rol.permiso_ids
  end

  def new
    @rol = Rol.new
    authorize @rol
  end

  def create
    @rol = Rol.new(rol_params)
    authorize @rol

    if @rol.save
      redirect_to role_path(@rol), notice: "Rol creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @rol
  end

  def update
    authorize @rol
    if @rol.update(rol_params)
      redirect_to role_path(@rol), notice: "Rol actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @rol
    if @rol.es_sistema?
      redirect_to roles_path, alert: "No se puede eliminar un rol de sistema."
    elsif @rol.users.any?
      redirect_to roles_path, alert: "No se puede eliminar un rol con usuarios asignados."
    else
      @rol.destroy
      redirect_to roles_path, notice: "Rol eliminado exitosamente."
    end
  end

  private

  def set_rol
    @rol = Rol.find(params[:id])
  end

  def rol_params
    params.require(:rol).permit(:nombre, :codigo, :descripcion, :logia_id)
  end
end
