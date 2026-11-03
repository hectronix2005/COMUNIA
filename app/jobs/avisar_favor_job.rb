# Cuando alguien pide una mano (Favor «pido»), avisa al momento a los demás miembros activos de su comunidad: a la
# campana y, si lo tienen activado, al teléfono. Los «ofrezco» no avisan: salen en el resumen de los lunes.
class AvisarFavorJob < ApplicationJob
  queue_as :default

  def perform(favor_id)
    favor = Favor.includes(:user, :logia).find_by(id: favor_id)
    return unless favor&.vigente? && favor.pido?

    comunidad = favor.logia.organizacion
    ids = [comunidad.id, *comunidad.logias.ids]
    titulo = "#{favor.user.nombre_corto} pide una mano".truncate(80)
    User.where(id: Miembro.where(logia_id: ids).activos.select(:user_id)).where.not(id: favor.user_id).find_each do |user|
      NotificacionService.crear!(user:, tipo: "favor_pido", titulo:, cuerpo: favor.titulo, url: "/favores/#{favor.id}", logia: comunidad)
    end
  end
end
