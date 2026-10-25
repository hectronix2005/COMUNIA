module Red
  # Cloudflare Turnstile para lo público de la red (registro, contacto sin cuenta, reportes sin cuenta).
  # Las mismas claves que DENUNCIAPP (TURNSTILE_SITE_KEY / TURNSTILE_SECRET), en la cuenta de Cloudflare
  # de Héctor. Sin clave solo se acepta en desarrollo y pruebas; en producción, sin ella, esos formularios
  # quedan cerrados (Red::BaseController#captcha_disponible?).
  module Captcha
    URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

    module_function

    def configurado? = ENV["TURNSTILE_SECRET"].present? && ENV["TURNSTILE_SITE_KEY"].present?

    def site_key = ENV["TURNSTILE_SITE_KEY"].presence

    # En pruebas se sustituye con Red::Captcha.verificador = ->(token) { … }
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
