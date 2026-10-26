module Denuncias
  # Base de DENUNCIAPP dentro de COMUNIA. El muro, los términos y las fotos son públicos; denunciar y
  # «Mis denuncias» piden sesión y ficha activa (ReportesController).
  class BaseController < ::ApplicationController
    layout "denuncias"

    skip_before_action :authenticate_user!
    # Una cuenta solo de la red también puede ver el muro (no denunciar).
    skip_before_action :confinar_cuenta_red
    # El muro es uno para todas las comunidades: sin el prefijo /t/<slug> que pondría un enlace de dentro.
    before_action :sin_prefijo_de_comunidad

    helper_method :disponible?, :captcha_site_key

    private

    def sin_prefijo_de_comunidad
      return if request.script_name.blank? || !request.get?
      redirect_to "#{request.path_info}#{"?#{request.query_string}" if request.query_string.present?}"
    end

    def limite?(accion, llave) = Limitador.global.permitir(accion, llave)

    def captcha_site_key = Denuncias.turnstile_site_key

    # En producción, sin clave maestra o sin Turnstile (el retiro de terceros es público) no se
    # aceptan denuncias.
    def disponible?
      Cripto.clave_maestra && (Captcha.configurado? || Rails.env.local?)
    rescue Cripto::ClaveInvalida
      false
    end

    def no_encontrado = render("denuncias/shared/no_encontrado", status: :not_found)

    # Solo escalares, recortados.
    def texto(v, min, max)
      return nil unless v.is_a?(String)
      t = v.strip
      t if t.length.between?(min, max)
    end
  end
end
