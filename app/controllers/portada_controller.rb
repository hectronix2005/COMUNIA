# Portada pública (rediseño del 29-oct-2026): a quien llega sin sesión le cuenta qué es COMUNIA y cómo empezar.
# Con sesión sigue a su inicio; dentro de una comunidad (/t/<slug>/) va al ingreso con la marca de esa comunidad.
class PortadaController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    return redirect_to(dashboard_path) if user_signed_in?
    redirect_to(new_user_session_path) if request.script_name.present?
  end
end
