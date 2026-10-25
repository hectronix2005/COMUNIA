module Red
  # Avisos de la red (las notificaciones de COMUNIA de tipo red_*), con el aspecto de la red.
  class AvisosController < BaseController
    def index
      @avisos = current_user.notificaciones.where("tipo LIKE 'red\\_%'").order(created_at: :desc).page(params[:page]).per(30).load
      current_user.notificaciones.where("tipo LIKE 'red\\_%'").no_leidas.update_all(leida: true, leida_at: Time.current)
    end
  end
end
