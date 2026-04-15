class TenantLogiasController < ApplicationController
  before_action :require_platform_admin!
  before_action :set_tenant
  before_action :set_logia, only: [:edit, :update, :destroy]

  def new
    @logia = @tenant.logias.build
    authorize @logia, :create?, policy_class: LogiaPolicy
  end

  def create
    @logia = @tenant.logias.build(logia_params)
    authorize @logia, :create?, policy_class: LogiaPolicy

    if @logia.save
      redirect_to tenant_path(@tenant), notice: "Logia «#{@logia.nombre}» creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @logia, :update?, policy_class: LogiaPolicy
  end

  def update
    authorize @logia, :update?, policy_class: LogiaPolicy
    if @logia.update(logia_params)
      redirect_to tenant_path(@tenant), notice: "Logia «#{@logia.nombre}» actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @logia, :destroy?, policy_class: LogiaPolicy
    @logia.destroy
    redirect_to tenant_path(@tenant), notice: "Logia eliminada."
  end

  private

  def set_tenant
    @tenant = Logia.tenants_raiz.find(params[:tenant_id])
  end

  def set_logia
    @logia = @tenant.logias.find(params[:id])
  end

  def logia_params
    params.require(:logia).permit(:nombre, :codigo)
  end

  def require_platform_admin!
    unless platform_admin_context?
      redirect_to root_path, alert: "Acceso exclusivo al administrador de plataforma."
    end
  end
end
