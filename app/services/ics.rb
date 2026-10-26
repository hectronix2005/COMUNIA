# Archivo iCalendar (RFC 5545) de un evento, para que cada quien lo añada al calendario de su teléfono, que es
# el que avisa. Sin gema: un VEVENT con el texto escapado y las líneas plegadas a 75 bytes.
module Ics
  module_function

  def evento(uid:, titulo:, inicio:, fin:, todo_el_dia: false, ubicacion: nil, descripcion: nil, url: nil)
    fechas = if todo_el_dia
      ["DTSTART;VALUE=DATE:#{inicio.to_date.strftime('%Y%m%d')}", "DTEND;VALUE=DATE:#{(fin.to_date + 1).strftime('%Y%m%d')}"]
    else
      ["DTSTART:#{utc(inicio)}", "DTEND:#{utc(fin)}"]
    end
    lineas = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//COMUNIA//ES", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
              "BEGIN:VEVENT", "UID:#{uid}", "DTSTAMP:#{utc(Time.current)}", *fechas, "SUMMARY:#{texto(titulo)}"]
    lineas << "LOCATION:#{texto(ubicacion)}" if ubicacion.present?
    lineas << "DESCRIPTION:#{texto([descripcion.presence, url].compact.join("\n\n"))}" if descripcion.present? || url
    lineas << "URL:#{url}" if url
    lineas.push("END:VEVENT", "END:VCALENDAR")
    lineas.map { plegar(_1) }.join("\r\n") + "\r\n"
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
