# Cada hora: a los eventos del calendario que empiezan en las próximas 24 h y aún no tuvieron recordatorio, se
# les manda uno (una sola vez por evento). Los de una reunión ya los recuerda RecordatorioReunionesJob.
# Se avisa a los miembros activos del grupo del evento (o de toda la comunidad si es de la raíz), menos a
# quien ya dijo que no va.
class RecordatorioEventosJob < ApplicationJob
  queue_as :default

  def perform
    CalendarioEvento.where.missing(:reunion).where(recordatorio_enviado_at: nil, inicio: Time.current..24.hours.from_now)
                    .includes(:logia).find_each do |evento|
      evento.update_column(:recordatorio_enviado_at, Time.current)
      titulo, cuerpo = textos(evento)
      destinatarios(evento).find_each do |user|
        NotificacionService.crear!(user: user, tipo: "evento_recordatorio", titulo: titulo.truncate(120), cuerpo: cuerpo,
                                   url: "/calendario/#{evento.id}", logia: evento.logia)
      end
    end
  end

  private

  def textos(evento)
    cuando = evento.inicio.to_date == Date.current ? "Hoy" : "Mañana"
    hora = evento.todo_el_dia ? "Todo el día" : I18n.l(evento.inicio, format: "%H:%M")
    ["#{cuando}: #{evento.titulo}", "#{hora}#{" · #{evento.ubicacion}" if evento.ubicacion.present?}. ¿Vas a ir?"]
  end

  def destinatarios(evento)
    logia = evento.logia
    ids = logia.tenant_id ? [logia.id] : [logia.id, *logia.logias.ids]
    User.where(id: Miembro.activos.where(logia_id: ids).select(:user_id))
        .where.not(id: evento.evento_confirmaciones.rechazados.select(:user_id))
  end
end
