module Red
  # Entrar a la red: Devise (con su bloqueo por intentos), con la plantilla de la red y vuelta a /red.
  # Las cuentas de la red entran con su correo (User.find_for_database_authentication).
  class SesionesController < Devise::SessionsController
    layout "red"
    skip_before_action :confinar_cuenta_red, raise: false

    helper_method :moderador?, :mi_perfil

    private

    def moderador? = false

    def mi_perfil = nil

    def after_sign_in_path_for(resource)
      stored_location_for(resource) || (resource.solo_red? ? red_inicio_path : dashboard_path)
    end
  end
end
