# Modo invitado: sin cuenta, se entra con la cuenta compartida a la comunidad de demostración (Demo) para ver
# cómo funciona. Mira todo y no guarda nada (ApplicationController#solo_lectura_para_invitado); para participar,
# entra con su cuenta o pide acceso a su comunidad (PedirAccesoController). Límite de intentos en rack_attack.rb.
class DemoController < ApplicationController
  skip_before_action :authenticate_user!, only: :create
  before_action :solo_invitado, except: :create

  def create
    return redirect_to(root_path) if user_signed_in? && !current_user.invitado?
    return redirect_to(new_user_session_path, alert: "La demostración no está disponible ahora.") unless Demo.disponible?

    session.delete(:tenant_slug)
    sign_in(Demo.invitado)
    redirect_to "/dashboard"
  end

  def participar; end

  # Cierra la sesión del invitado y lleva a entrar o a pedir acceso.
  def destroy
    sign_out(current_user)
    session.delete(:tenant_slug)
    # Sin el prefijo /t/demostracion: el login y la solicitud no llevan la marca de la demostración.
    redirect_to params[:destino] == "pedir" ? "/pedir-acceso" : "/login", status: :see_other
  end

  private

  def solo_invitado
    redirect_to root_path unless current_user.invitado?
  end
end
