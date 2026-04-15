class TenantLoginsController < Devise::SessionsController
  prepend_before_action :set_tenant_context

  private

  def set_tenant_context
    logia = Logia.tenants_raiz.find_by(slug: params[:tenant_slug])
    if logia.nil?
      redirect_to new_user_session_path, alert: "Tenant no encontrado."
    else
      session[:tenant_slug] = logia.slug
    end
  end
end
