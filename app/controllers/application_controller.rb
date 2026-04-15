class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  before_action :capture_tenant_slug_from_script_name
  before_action :clear_tenant_context_on_platform_login
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_miembro, :current_logia, :display_logia

  def current_miembro
    @current_miembro ||= current_user&.miembro
  end

  # Para scoping de datos: siempre tiene valor (fallback a primera logia).
  def current_logia
    @current_logia ||= resolve_tenant
  end

  # Para branding visual: nil cuando es contexto de plataforma (sin subdominio, sin usuario, sin preview).
  # Evita mostrar el branding de un tenant específico en la pantalla de admin/login genérico.
  def display_logia
    return @display_logia if defined?(@display_logia)
    @display_logia = if previewing_tenant? || tenant_subdomain.present?
      current_logia
    elsif current_user&.logia_id.present?
      current_user.logia
    end
    # nil implícito → branding neutro de plataforma
    @display_logia
  end

  private

  # Extrae el subdominio directamente del host (evita bugs de request.subdomain con .localhost).
  # "freemasons.localhost" → "freemasons" | "localhost" → nil
  # Si el host no tiene subdominio (p. ej. *.herokuapp.com), cae a session[:tenant_slug].
  def tenant_subdomain
    parts = request.host.split(".")
    host_sub = parts.length > 1 ? parts.first : nil
    return host_sub if host_sub && Logia.exists?(slug: host_sub)
    session[:tenant_slug].presence
  end

  # Tenant resolution priority:
  #   1. Super-admin preview session override
  #   2. Subdomain in the request (freemasons.localhost → slug "freemasons")
  #   3. Logged-in user's assigned logia
  #   4. First logia (fallback for super-admins without subdomain)
  def resolve_tenant
    if session[:preview_logia_id].present? && current_user&.rol_ref&.es_super_admin?
      return Logia.find_by(id: session[:preview_logia_id]) || Logia.ordenadas.first
    end
    if (sub = tenant_subdomain) && (logia = Logia.find_by(slug: sub))
      return logia
    end
    current_user&.logia || Logia.ordenadas.first
  end

  helper_method :previewing_tenant?, :platform_admin_context?

  def previewing_tenant?
    session[:preview_logia_id].present? && current_user&.rol_ref&.es_super_admin?
  end

  # Contexto de plataforma: super admin sin subdominio y sin preview activo.
  # En este contexto se muestran todos los tenants.
  def platform_admin_context?
    current_user&.rol_ref&.es_super_admin? &&
      tenant_subdomain.blank? &&
      !previewing_tenant?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:nombre, :apellido])
  end

  # Al visitar /login (plataforma COMUNIA, sin prefijo de tenant) limpiamos
  # cualquier tenant_slug pegado en sesión por una visita previa.
  def clear_tenant_context_on_platform_login
    return if request.script_name.present?
    return unless request.fullpath.start_with?("/login")
    session.delete(:tenant_slug)
  end

  # El middleware TenantPathPrefix pone /t/:slug en SCRIPT_NAME. Lo validamos
  # y replicamos a session[:tenant_slug] para el resto del código que aún
  # depende de la sesión (p. ej. resolve_tenant en hosts sin subdominio).
  def capture_tenant_slug_from_script_name
    return if request.script_name.blank?
    m = request.script_name.match(%r{\A/t/([a-z0-9][a-z0-9\-_]*)\z})
    return unless m
    slug = m[1]
    if Logia.tenants_raiz.exists?(slug: slug)
      session[:tenant_slug] = slug
    else
      session.delete(:tenant_slug)
      redirect_to "/", alert: "Tenant no encontrado."
    end
  end

  def user_not_authorized
    flash[:alert] = "No tienes permiso para realizar esta acción."
    redirect_back(fallback_location: root_path)
  end

  # Restringe el acceso a un módulo al usuario que tenga el cargo indicado
  # (vigente) en su ficha de miembro. admin_logia y super_admin pasan siempre.
  def require_cargo!(nombre_cargo)
    return if current_user&.tiene_cargo?(nombre_cargo)
    flash[:alert] = "Acceso restringido: requiere el cargo de #{nombre_cargo}."
    redirect_to dashboard_path
  end

  def require_tesorero!
    require_cargo!("Tesorero")
  end

  def require_hospitalario!
    require_cargo!("Hospitalario")
  end

  def after_sign_in_path_for(resource)
    # dashboard_path respeta request.script_name automáticamente, por lo que
    # si el login fue en /t/:slug/login, el redirect será /t/:slug/dashboard.
    dashboard_path
  end
end
