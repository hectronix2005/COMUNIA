class TenantAccessController < ApplicationController
  def enter
    logia = Logia.tenants_raiz.find_by(slug: params[:slug])
    return redirect_to root_path, alert: "Tenant no encontrado." if logia.nil?

    unless puede_acceder?(logia)
      return redirect_to root_path, alert: "No tienes acceso a ese tenant."
    end

    session[:tenant_slug] = logia.slug
    redirect_to root_path, notice: "Accediendo a #{logia.nombre_display}."
  end

  def exit_tenant
    session.delete(:tenant_slug)
    redirect_to root_path, notice: "Saliste del contexto del tenant."
  end

  private

  def puede_acceder?(logia)
    return true if current_user.rol_ref&.es_super_admin?
    user_tenant_root = current_user.logia&.tenant || current_user.logia
    user_tenant_root == logia
  end
end
