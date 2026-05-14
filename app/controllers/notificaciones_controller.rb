class NotificacionesController < ApplicationController
  def index
    @notificaciones = current_user.notificaciones.recientes.includes(:logia)
    render layout: false
  end

  def leer
    notificacion = current_user.notificaciones.find(params[:id])
    notificacion.marcar_leida!
    NotificacionService.broadcast_badge(current_user)
    head :ok
  end

  def leer_todas
    current_user.notificaciones.no_leidas.update_all(leida: true, leida_at: Time.current)
    NotificacionService.broadcast_badge(current_user)
    head :ok
  end
end
