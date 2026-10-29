# Formularios que se envían sin cuenta (el registro de la red, pedir acceso a una comunidad): solo admiten
# texto escalar y exigen captcha. El límite de intentos de cada uno está en config/initializers/rack_attack.rb.
module FormularioPublico
  extend ActiveSupport::Concern

  included do
    helper_method :captcha_site_key
  end

  private

  # Solo escalares: un parámetro con forma de hash o lista cuenta como vacío.
  def texto(clave, max = 200)
    v = params[clave]
    v.is_a?(String) ? v.strip[0, max] : nil
  end

  def captcha_site_key = Red::Captcha.site_key

  # En producción sin Turnstile no se aceptan formularios públicos sin cuenta (regla de seguridad).
  def captcha_disponible? = Red::Captcha.disponible?

  def captcha_valido? = Red::Captcha.valido?(params["cf-turnstile-response"])
end
