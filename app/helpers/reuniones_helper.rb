module ReunionesHelper
  # Mensaje para pegar en el grupo de WhatsApp de la comunidad: antes, la convocatoria; con el acta publicada, que ya
  # está. Solo lleva el título, la fecha, el lugar y el enlace: el orden del día y el acta no salen de COMUNIA.
  def texto_whatsapp_reunion(reunion, url)
    if reunion.acta_publicada?
      "Ya está publicada el acta de «#{reunion.titulo}» (#{l(reunion.inicio, format: '%-d de %B')}). Léela en COMUNIA: #{url}"
    else
      lugar = " · #{reunion.lugar}" if reunion.lugar.present?
      "#{reunion.nombre}\n#{l(reunion.inicio, format: '%A %-d de %B').capitalize}, de #{reunion.inicio.strftime('%H:%M')} " \
        "a #{reunion.fin.strftime('%H:%M')}#{lugar}\nConfirma si vas, mira el orden del día y propón puntos en COMUNIA: #{url}"
    end
  end

  # Pregunta personal a quien no ha respondido, con el mismo cuidado: sin orden del día.
  def texto_whatsapp_pregunta(reunion, user, url)
    "Hola, #{user.nombre}. ¿Vienes a «#{reunion.titulo}» el #{l(reunion.inicio, format: '%A %-d de %B')} a las " \
      "#{reunion.inicio.strftime('%H:%M')}? Confírmalo aquí: #{url}"
  end
end
