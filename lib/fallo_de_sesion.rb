# Cuando Devise echa a alguien (sesión caducada, sin cuenta…), quien estaba en la red vuelve al login
# de la red y no al de las logias.
class FalloDeSesion < Devise::FailureApp
  def route(scope)
    request.path.start_with?("/red") ? :red_entrar_url : super
  end
end
