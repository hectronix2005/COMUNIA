# Archivo iCalendar (RFC 5545) para que cada quien lleve sus eventos al calendario del teléfono, que es el que
# avisa: uno suelto o la suscripción entera. Sin gema: VEVENT con el texto escapado y las líneas plegadas a 75
# bytes.
module Ics
  module_function

  def evento(**datos) = calendario([datos])

  # La suscripción lleva nombre y pide al teléfono que la actualice cada pocas horas.
  def calendario(eventos, nombre: nil, refrescar: nil)
    lineas = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//COMUNIA//ES", "CALSCALE:GREGORIAN", "METHOD:PUBLISH"]
    lineas << "X-WR-CALNAME:#{texto(nombre)}" if nombre
    lineas.push("REFRESH-INTERVAL;VALUE=DURATION:#{refrescar}", "X-PUBLISHED-TTL:#{refrescar}") if refrescar
    eventos.each { lineas.concat(vevento(**_1)) }
    lineas << "END:VCALENDAR"
    lineas.map { plegar(_1) }.join("\r\n") + "\r\n"
  end

  def vevento(uid:, titulo:, inicio:, fin:, todo_el_dia: false, ubicacion: nil, descripcion: nil, url: nil)
    fechas = if todo_el_dia
      ["DTSTART;VALUE=DATE:#{inicio.to_date.strftime('%Y%m%d')}", "DTEND;VALUE=DATE:#{(fin.to_date + 1).strftime('%Y%m%d')}"]
    else
      ["DTSTART:#{utc(inicio)}", "DTEND:#{utc(fin)}"]
    end
    lineas = ["BEGIN:VEVENT", "UID:#{uid}", "DTSTAMP:#{utc(Time.current)}", *fechas, "SUMMARY:#{texto(titulo)}"]
    lineas << "LOCATION:#{texto(ubicacion)}" if ubicacion.present?
    lineas << "DESCRIPTION:#{texto([descripcion.presence, url].compact.join("\n\n"))}" if descripcion.present? || url
    lineas << "URL:#{url}" if url
    lineas << "END:VEVENT"
  end

  def utc(tiempo) = tiempo.utc.strftime("%Y%m%dT%H%M%SZ")

  def texto(valor)
    valor.to_s.gsub(/[\;,]/) { "\\#{_1}" }.gsub(/\r?\n/, "\\n")
  end

  # Líneas de más de 75 bytes se parten y la continuación empieza con un espacio, sin cortar un carácter.
  def plegar(linea)
    partes = [+""]
    linea.each_char do |c|
      partes << +" " if partes.last.bytesize + c.bytesize > 75
      partes.last << c
    end
    partes.join("\r\n")
  end
end
