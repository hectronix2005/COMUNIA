# Cuando Devise echa a alguien (sesión caducada, sin cuenta…), quien estaba en la red vuelve al login
# de la red y no al de las logias.
class FalloDeSesion < Devise::FailureApp
  def route(scope)
    request.path.start_with?("/red") ? :red_entrar_url : super
  end

  protected

  # Solo se recuerda, para volver tras entrar, una página que la persona abrió. El panel de avisos se carga en
  # segundo plano (turbo-frame) y, con la sesión caducada, dejaba /notificaciones como destino: al entrar salía
  # esa lista suelta, sin estilos (Héctor, 1-nov-2026). Lo mismo con lo que Turbo precarga al pasar el ratón.
  def store_location!
    return if request.headers["Turbo-Frame"].present?
    return if request.headers["X-Sec-Purpose"].to_s.include?("prefetch") || request.headers["Purpose"] == "prefetch"

    super
  end
end
