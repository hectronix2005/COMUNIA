# Cómo se lee cada evento del rastreo de pruebas en /rastreo.
module RastreoHelper
  NOMBRES = {
    "Petición" => "Servidor", "$view" => "Abrió", "Tiempo en vista" => "Estuvo", "$click" => "Clic",
    "$submit" => "Envió", "Error del navegador" => "Error", "Pestaña oculta" => "Se fue de la pestaña",
    "Pestaña visible" => "Volvió a la pestaña"
  }.freeze

  def duracion_rastreo(segundos)
    segundos = segundos.to_i
    return "#{segundos} s" if segundos < 60
    return "#{segundos / 60} min #{segundos % 60} s" if segundos < 3600
    "#{segundos / 3600} h #{(segundos % 3600) / 60} min"
  end

  def tipo_evento(evento)
    NOMBRES.fetch(evento.name, evento.name)
  end

  # [página o acción, detalle, clase de la fila]
  def lectura_evento(evento)
    p = evento.properties || {}
    case evento.name
    when "Petición"
      estado = p["estado"].to_i
      detalle = [p["metodo"] == "GET" ? nil : p["metodo"], "#{estado} · #{p['ms']} ms", p["marco"] && "marco #{p['marco']}",
        p["destino"] && "→ #{p['destino']}", p["error"], p["alerta"] && "Aviso rojo: #{p['alerta']}", p["aviso"] && "Aviso: #{p['aviso']}"]
      fila = if estado >= 500 then "table-danger" elsif estado >= 400 || p["alerta"] then "table-warning" end
      ["#{p['ruta']} (#{p['accion']})", detalle.compact.join(" · "), fila]
    when "$view" then [p["page"], [p["title"], p["pantalla"]].compact.join(" · "), "table-info"]
    when "Tiempo en vista"
      [p["page"], "#{duracion_rastreo(p['segundos_visible'])} a la vista (#{duracion_rastreo(p['segundos'])} en total; #{p['motivo']})", nil]
    when "$click" then [p["page"], [p["tag"], p["texto"].presence && "«#{p['texto']}»", p["href"] && "→ #{p['href']}"].compact.join(" "), nil]
    when "$submit" then [p["page"], "formulario #{p['metodo']} #{p['accion']}", nil]
    when "Error del navegador"
      [p["page"], [p["tipo"], p["mensaje"], p["archivo"] && "#{p['archivo']}:#{p['linea']}"].compact.join(" · "), "table-danger"]
    else [p["page"], p.except("page").to_json, nil]
    end
  end

  # Dónde terminó la visita: la última página que abrió o, si no hay vistas, la última petición.
  def final_de_visita(eventos)
    ultimo = eventos.reverse.find { |e| e.name.in?(["$view", "Petición"]) && !(e.name == "Petición" && e.properties["metodo"] != "GET") }
    ultimo && (ultimo.properties["page"] || ultimo.properties["ruta"])
  end
end
