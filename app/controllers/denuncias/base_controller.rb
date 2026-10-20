module Denuncias
  # Base de todo lo que se sirve en el host de DENUNCIAPP. A propósito NO hereda de
  # ApplicationController: nada de current_user, Devise de COMUNIA, last_seen_at, tenants ni
  # analítica. La IP solo se usa en memoria para el límite de intentos (Limitador).
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout false

    before_action :solo_en_su_host
    after_action { response.headers["Referrer-Policy"] = "no-referrer" }

    content_security_policy do |p|
      p.default_src :self
      p.script_src :self, "https://challenges.cloudflare.com"
      p.frame_src "https://challenges.cloudflare.com"
      p.connect_src :self
      p.img_src :self, :blob
      p.style_src :self
      p.object_src :none
      p.base_uri :none
      p.frame_ancestors :none
      p.form_action :self
    end

    rescue_from ActionController::InvalidAuthenticityToken do
      render json: { error: "La sesión de la página venció; recárgala" }, status: :unprocessable_content
    end

    private

    def solo_en_su_host
      head :not_found unless Denuncias.host?(request)
    end

    # Para el límite en memoria; nunca se guarda ni se registra.
    def ip_efimera = request.remote_ip.to_s

    def limite!(accion, llave = ip_efimera)
      return true if Limitador.global.permitir(accion, llave)
      render json: { error: "Demasiados intentos; espera una hora" }, status: :too_many_requests
      false
    end

    # Rutas que actúan con la cookie de la cuenta de alias: la petición tiene que venir del sitio.
    def mismo_origen?
      origen = request.headers["Origin"].presence or return false
      URI(origen).host.to_s.casecmp?(request.host)
    rescue URI::InvalidURIError
      false
    end

    def cuenta_actual
      return nil unless Denuncias.cuentas?
      c = current_cuenta
      c if c&.email_verificado
    end

    # En producción, sin clave maestra o sin Turnstile no se aceptan denuncias (regla de seguridad).
    def disponible?
      Cripto.clave_maestra && (Captcha.configurado? || Rails.env.local?)
    rescue Cripto::ClaveInvalida
      false
    end
  end
end
