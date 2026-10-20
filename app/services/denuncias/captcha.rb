module Denuncias
  # Cloudflare Turnstile. Se verifica SIN remoteip: la IP del denunciante no sale del servidor.
  # Sin TURNSTILE_SECRET solo se acepta en desarrollo y pruebas; en producción, sin él, el
  # módulo no recibe denuncias (Denuncias::BaseController#disponible?).
  module Captcha
    URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

    module_function

    def configurado? = ENV["TURNSTILE_SECRET"].present?

    # En pruebas se sustituye con Denuncias::Captcha.verificador = ->(token) { … }
    mattr_accessor :verificador

    def valido?(token)
      return verificador.call(token) if verificador
      return Rails.env.local? unless configurado?
      return false unless token.is_a?(String) && token.present? && token.bytesize <= 2048

      r = Net::HTTP.post_form(URL, "secret" => ENV["TURNSTILE_SECRET"], "response" => token)
      JSON.parse(r.body)["success"] == true
    rescue StandardError
      false
    end
  end
end
