# Avisa a los convocados de una reunión: convocatoria (de una fecha o de una serie), cambio, cancelación,
# votación abierta o acta publicada.
# Solo a los miembros activos del grupo convocado (o de toda la comunidad si es de la raíz).
class NotificarReunionJob < ApplicationJob
  queue_as :default

  TEXTOS = {
    "convocatoria" => ->(r, _detalle) { ["#{r.logia.t_reunion}: #{r.titulo}", "#{I18n.l(r.inicio, format: '%a %-d %b, %H:%M')}#{" · #{r.lugar}" if r.lugar.present?}"] },
    "cambio"       => ->(r, _detalle) { ["Cambio de fecha o lugar: #{r.titulo}", "Ahora: #{I18n.l(r.inicio, format: '%a %-d %b, %H:%M')}#{" · #{r.lugar}" if r.lugar.present?}"] },
    "cancelada"    => ->(r, _detalle) { ["Se canceló: #{r.titulo}", "Estaba prevista el #{I18n.l(r.inicio, format: '%a %-d %b, %H:%M')}."] },
    "acta"         => ->(r, _detalle) { ["Acta publicada: #{r.titulo}", "Ya puedes leer el acta."] },
    "votacion"     => ->(r, pregunta) { ["Votación abierta: #{pregunta}", "En «#{r.titulo}». Entra a votar."] },
    "serie"        => ->(r, detalle) { ["#{r.logia.t_reuniones}: #{r.titulo}", "#{detalle}. La primera: #{I18n.l(r.inicio, format: '%a %-d %b, %H:%M')}#{" · #{r.lugar}" if r.lugar.present?}"] },
    "serie_cancelada" => ->(r, veces) { ["Se cancelaron #{veces} fechas: #{r.titulo}", "Desde el #{I18n.l(r.inicio, format: '%a %-d %b')} en adelante."] },
    "recordatorio" => ->(r, _detalle) { ["Mañana: #{r.titulo}", "#{I18n.l(r.inicio, format: '%H:%M')}#{" · #{r.lugar}" if r.lugar.present?}. ¿Vas a ir?"] }
  }.freeze

  def perform(reunion_id, motivo, detalle = nil)
    reunion = Reunion.find_by(id: reunion_id)
    texto = TEXTOS[motivo]
    return unless reunion && texto

    titulo, cuerpo = texto.call(reunion, detalle)
    destinatarios(reunion, motivo).find_each do |user|
      NotificacionService.crear!(user: user, tipo: "reunion_#{motivo}", titulo: titulo.truncate(120), cuerpo: cuerpo,
                                 url: "/reuniones/#{reunion.id}", logia: reunion.logia)
    end
  end

  private

  # El recordatorio no se manda a quien ya dijo que no va; los demás avisos, a todos los convocados.
  def destinatarios(reunion, motivo)
    users = User.where(id: reunion.convocados.select(:user_id))
    users = users.where.not(id: reunion.confirmaciones.rechazados.select(:user_id)) if motivo == "recordatorio"
    users = users.where.not(id: reunion.user_id) unless motivo == "recordatorio"
    users
  end
end
