class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  before_action :capture_tenant_slug_from_script_name
  before_action :clear_tenant_context_on_platform_login
  before_action :authenticate_user!
  before_action :confinar_cuenta_red
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action  :track_last_seen

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
  # Si el host no tiene subdominio de logia (p. ej. comunia.tail0be41e.ts.net), cae a session[:tenant_slug].
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
    if (sub = tenant_subdomain) && (logia = Logia.find_by(slug: sub)) && tenant_permitido?(logia)
      return logia
    end
    current_user&.logia || Logia.ordenadas.first
  end

  # El tenant de la URL o de la sesión solo cuenta si es el del usuario: sin esto, cambiar /t/<slug>
  # bastaba para ver el directorio, el chat o el calendario de otra organización.
  def tenant_permitido?(logia)
    return true if current_user.nil? || current_user.rol_ref&.es_super_admin?
    propia = current_user.logia or return false
    (propia.tenant_id || propia.id) == (logia.tenant_id || logia.id)
  end

  # Logias de la organización actual: la raíz y sus hijas. Lo que un miembro abre por id (una ficha, una
  # publicación, un evento) se busca dentro de estas; lo de otra organización da el mismo 404 que lo que no
  # existe.
  def logia_ids_de_la_organizacion
    @logia_ids_de_la_organizacion ||= begin
      raiz = current_logia.tenant || current_logia
      [raiz.id, *raiz.logias.ids]
    end
  end

  def logia_ids_visibles
    logia_ids_de_la_organizacion
  end

  # Logias en las que el usuario gestiona lo de otros (borrar, fijar, cerrar): la suya, también las hijas si
  # es de la raíz, y todas las de la organización para el superadmin.
  def logia_ids_gestionables
    return logia_ids_de_la_organizacion if current_user.rol_ref&.es_super_admin?
    Array(current_user.logia_ids_accesibles) & logia_ids_de_la_organizacion
  end

  # Un admin modera (borra, fija, cierra) lo publicado en las logias que gestiona, no en las demás. El rol
  # es el de rol_ref, como los permisos: el enum rol de users no siempre coincide con él.
  def modera?(registro)
    return true if current_user.rol_ref&.es_super_admin?
    current_user.rol_ref&.codigo == "admin_logia" && logia_ids_gestionables.include?(registro.logia_id)
  end

  # Logias que el usuario administra (cuotas, conceptos, cortes, tarifas): todas para el superadmin; para
  # los demás, las de logia_ids_accesibles. Lo de otra logia da 404.
  def logias_administrables
    return Logia.all if current_user.rol_ref&.es_super_admin?
    Logia.where(id: Array(current_user.logia_ids_accesibles))
  end

  # Logias cuya tesorería se muestra (cobros, reportes): las accesibles del usuario; para el superadmin, las de
  # la organización en la que está, o todas (nil) en el panel de plataforma.
  def logia_ids_tesoreria
    return current_user.logia_ids_accesibles unless current_user.rol_ref&.es_super_admin?
    logia_ids_de_la_organizacion unless platform_admin_context?
  end

  # Logias para el filtro de tesorería: vacío si solo hay una.
  def logias_tesoreria
    ids = logia_ids_tesoreria
    logias = ids ? Logia.where(id: ids).ordenadas : Logia.ordenadas
    logias.many? ? logias : Logia.none
  end

  # Periodos de cobro que se ofrecen: los de la organización actual; en el panel de plataforma, todos.
  def periodos_visibles
    periodos = policy_scope(PeriodoCobro)
    platform_admin_context? ? periodos : periodos.de_organizacion(current_logia.organizacion)
  end

  helper_method :previewing_tenant?, :platform_admin_context?, :modera?

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
    if (logia = Logia.tenants_raiz.find_by(slug: slug))
      unless tenant_permitido?(logia)
        session.delete(:tenant_slug)
        # Ruta sin prefijo: el dashboard lleva al usuario a su propio tenant.
        return redirect_to("/dashboard", alert: "No tienes acceso a ese tenant.")
      end
      session[:tenant_slug] = slug
    else
      session.delete(:tenant_slug)
      redirect_to "/", alert: "Tenant no encontrado."
    end
  end

  # Las cuentas que solo usan la red no tienen logia: el resto de COMUNIA (que cae a la primera logia
  # cuando falta la del usuario) les queda cerrado. Solo /red, su sesión, notificaciones y la PWA.
  CONTROLADORES_PARA_CUENTAS_RED = %w[notificaciones push_subscriptions pwa].freeze

  def confinar_cuenta_red
    return unless current_user&.solo_red?
    return if devise_controller? || controller_path.start_with?("red/") || controller_path.in?(CONTROLADORES_PARA_CUENTAS_RED)
    redirect_to red_inicio_path
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

  # Tras cerrar sesión, si el usuario estaba dentro de un tenant
  # (/t/:slug/...) lo devolvemos al login del MISMO tenant en lugar del
  # /login global de COMUNIA.
  def after_sign_out_path_for(resource_or_scope)
    m = request.script_name.to_s.match(%r{\A/t/([a-z0-9][a-z0-9\-_]*)\z})
    m ? "/t/#{m[1]}/login" : new_user_session_path
  end

  def track_last_seen
    current_user&.touch_last_seen! if current_user
  rescue StandardError
    # Non-critical, never break the request
  end
end
