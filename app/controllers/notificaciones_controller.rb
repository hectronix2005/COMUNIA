class NotificacionesController < ApplicationController
  # Solo los avisos de la comunidad que se mira y los personales; de sus otras comunidades, cuántos hay sin leer.
  def index
    @notificaciones = notificaciones_visibles.recientes.includes(logia: :tenant)
    @otras_comunidades = otras_comunidades_con_avisos
    render layout: false
  end

  def leer
    notificacion = current_user.notificaciones.find(params[:id])
    notificacion.marcar_leida!
    NotificacionService.broadcast_badge(current_user, notificaciones_visibles.no_leidas.count)
    head :ok
  end

  def leer_todas
    notificaciones_visibles.no_leidas.update_all(leida: true, leida_at: Time.current)
    NotificacionService.broadcast_badge(current_user, 0)
    head :ok
  end

  private

  # [[comunidad, sin leer]] de las otras comunidades a las que pertenece (no de las que dejó).
  def otras_comunidades_con_avisos
    return [] if platform_admin_context? || current_user.solo_red? || current_logia.nil?
    current_user.comunidades.where.not(id: current_logia.organizacion.id)
                .map { |comunidad| [comunidad, current_user.notificaciones.de_la_comunidad(comunidad).no_leidas.count] }
                .select { |_, sin_leer| sin_leer.positive? }
  end
end
