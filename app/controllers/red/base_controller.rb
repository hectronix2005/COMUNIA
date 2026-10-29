module Red
  # Base de la red de comunidades certificadas. Hereda de ApplicationController por Devise (la misma
  # cuenta sirve para la logia y para la red), pero no usa tenants: nada de current_logia aquí.
  #
  # Privacidad entre comunidades: lo que no existe y lo que no se puede ver responden igual
  # (`no_encontrado`), y ningún mensaje de error nombra una comunidad ajena.
  class BaseController < ::ApplicationController
    include FormularioPublico

    layout "red"

    skip_before_action :authenticate_user!
    before_action :exigir_cuenta

    helper_method :mi_perfil, :mis_comunidad_ids, :moderador?, :alcance_opciones

    rescue_from ActionController::ParameterMissing, with: :peticion_invalida
    rescue_from ActiveRecord::RecordNotFound, with: :no_encontrado

    # Acciones públicas: se declaran en cada controlador con `publico only: %i[...]`.
    def self.publico(**opciones) = skip_before_action(:exigir_cuenta, **opciones)
    # Páginas que se ven sin cuenta pero no deben quedar en los buscadores.
    def self.fuera_de_buscadores(**opciones) = after_action(**opciones) { response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive") }

    private

    def exigir_cuenta
      return if user_signed_in?
      store_location_for(:user, request.fullpath) if request.request_method_symbol == :get
      redirect_to red_entrar_path, alert: "Entra o crea tu cuenta para seguir."
    end

    def mi_perfil
      return @mi_perfil if defined?(@mi_perfil)
      @mi_perfil = current_user&.red_perfil
    end

    def exigir_perfil
      return if mi_perfil
      redirect_to red_bienvenida_path
    end

    def mis_comunidad_ids
      @mis_comunidad_ids ||= current_user ? Red.comunidades_de(current_user) : []
    end

    def moderador? = Red.moderador?(current_user)

    def exigir_moderador
      no_encontrado unless moderador?
    end

    # Una sola respuesta para «no existe» y «no puedes verlo».
    def no_encontrado
      respond_to do |f|
        f.json { render json: { error: "No encontrado" }, status: :not_found }
        f.any { render "red/shared/no_encontrado", status: :not_found, formats: :html }
      end
    end

    def peticion_invalida
      respond_to do |f|
        f.json { render json: { error: "Petición inválida" }, status: :bad_request }
        f.any { redirect_back fallback_location: red_inicio_path, alert: "Revisa el formulario." }
      end
    end

    # Opciones de alcance para formularios: las comunidades son SOLO las de quien edita.
    def alcance_opciones
      @alcance_opciones ||= Comunidad.where(id: mis_comunidad_ids).order(:nombre).pluck(:nombre, :id)
    end

    def after_sign_in_path_for(resource)
      stored_location_for(resource) || red_inicio_path
    end
  end
end
