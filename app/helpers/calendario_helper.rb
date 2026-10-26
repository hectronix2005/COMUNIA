module CalendarioHelper
  # Enlace para crear el evento en Google Calendar. Solo lleva el título, las horas, el lugar y el enlace a la
  # app: el resto de la descripción no sale de COMUNIA.
  def google_calendar_url(evento, url)
    fechas = if evento.todo_el_dia
      [evento.inicio.to_date, evento.fin.to_date + 1].map { _1.strftime("%Y%m%d") }
    else
      [evento.inicio, evento.fin].map { Ics.utc(_1) }
    end
    query = { action: "TEMPLATE", text: evento.titulo, dates: fechas.join("/"), location: evento.ubicacion.presence, details: url }
    "https://calendar.google.com/calendar/render?#{query.compact.to_query}"
  end
end
