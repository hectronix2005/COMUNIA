class TenantsController < ApplicationController
  before_action :require_platform_admin!, except: [:exit_preview]
  before_action :require_super_admin!, only: [:exit_preview]

  def index
    @tenants = Logia.tenants_raiz.order(:codigo).with_attached_logo
    # Counts agrupados para evitar N+1 (`tenant.logias.count` por card).
    @logias_count = Logia.where.not(tenant_id: nil).group(:tenant_id).count
  end

  def show
    @tenant = Logia.tenants_raiz.find(params[:id])
    authorize @tenant, :show?, policy_class: LogiaPolicy
    @logias = @tenant.logias.order(:codigo)
    @admins_tenant = admins_del_tenant(@tenant)
  end

  def new
    @tenant = Logia.new
    authorize @tenant, :create?, policy_class: LogiaPolicy
  end

  def create
    @tenant = Logia.new(tenant_params)
    authorize @tenant, :create?, policy_class: LogiaPolicy

    if @tenant.save
      redirect_to tenants_path, notice: "Tenant «#{@tenant.nombre_display}» creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tenant = Logia.find(params[:id])
    authorize @tenant, :update?, policy_class: LogiaPolicy
    @admins_tenant = admins_del_tenant(@tenant)
  end

  def update
    @tenant = Logia.find(params[:id])
    authorize @tenant, :update?, policy_class: LogiaPolicy

    if @tenant.update(tenant_params)
      if @tenant.tenant_id.present?
        redirect_to tenant_path(@tenant.tenant_id),
                    notice: "«#{@tenant.nombre_display}» ahora es una logia dentro del tenant padre."
      else
        redirect_to tenants_path, notice: "Tenant «#{@tenant.nombre_display}» actualizado."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tenant = Logia.find(params[:id])
    authorize @tenant, :destroy?, policy_class: LogiaPolicy

    if @tenant.miembros.any?
      redirect_to tenants_path, alert: "No se puede eliminar un tenant con miembros."
    else
      @tenant.destroy
      redirect_to tenants_path, notice: "Tenant eliminado."
    end
  end

  def crear_admin_tenant
    @tenant = Logia.tenants_raiz.find(params[:id])
    authorize @tenant, :update?, policy_class: LogiaPolicy

    p = admin_tenant_params
    rol = Rol.find_by!(codigo: "admin_logia")

    ActiveRecord::Base.transaction do
      user = User.new(
        nombre:    p[:nombre],
        apellido:  p[:apellido],
        email:     p[:email],
        password:  p[:password],
        rol:       :admin_logia,
        rol_ref:   rol,
        logia_id:  @tenant.id
      )
      if user.save
        redirect_to edit_tenant_path(@tenant), notice: "Administrador «#{user.nombre_completo}» (#{user.username}) creado."
      else
        @admins_tenant = admins_del_tenant(@tenant)
        flash.now[:alert] = user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def quitar_admin_tenant
    @tenant = Logia.tenants_raiz.find(params[:id])
    authorize @tenant, :update?, policy_class: LogiaPolicy

    user = User.find(params[:user_id])
    if user.logia_id == @tenant.id
      user.update!(rol: :miembro, rol_ref: Rol.find_by!(codigo: "miembro"))
      redirect_to edit_tenant_path(@tenant), notice: "#{user.nombre_completo} ya no es administrador del tenant."
    else
      redirect_to edit_tenant_path(@tenant), alert: "El usuario no pertenece a este tenant."
    end
  end

  def preview
    @tenant = Logia.find(params[:id])
    authorize @tenant, :show?, policy_class: LogiaPolicy
    session[:preview_logia_id] = @tenant.id
    @current_logia = nil
    redirect_to root_path, notice: "Previsualizando «#{@tenant.nombre_display}»"
  end

  def exit_preview
    session.delete(:preview_logia_id)
    @current_logia = nil
    redirect_to tenants_path, notice: "Vista previa finalizada."
  end

  private

  def require_platform_admin!
    unless platform_admin_context?
      redirect_to root_path, alert: "Acceso exclusivo al administrador de plataforma."
    end
  end

  def require_super_admin!
    unless current_user&.rol_ref&.es_super_admin?
      redirect_to root_path, alert: "Acceso denegado."
    end
  end

  def admins_del_tenant(tenant)
    User.where(logia_id: tenant.id)
        .joins(:rol_ref)
        .where(roles: { codigo: "admin_logia" })
        .order(:apellido, :nombre)
  end

  def admin_tenant_params
    params.require(:admin_tenant).permit(:nombre, :apellido, :email, :password)
  end

  def tenant_params
    params.require(:logia).permit(:nombre, :codigo, :slug, :tenant_id,
                                  :nombre_app, :icono, :lema, :color_primario,
                                  :termino_miembro, :termino_logia, :termino_cobro,
                                  :logo)
  end
end
