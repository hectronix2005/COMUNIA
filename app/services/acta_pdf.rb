require "prawn"

# El acta de una reunión en PDF, para archivarla o imprimirla: datos de la convocatoria, orden del día, asistencia con
# quórum, el acta, los acuerdos, las votaciones cerradas (con nombres solo si no fueron secretas) y si está aprobada.
module ActaPdf
  FUENTE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
  FUENTE_NEGRITA = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
  OPCIONES = { "si" => "Sí", "no" => "No", "abstencion" => "Abstención" }.freeze

  module_function

  def generar(reunion)
    ttf = File.exist?(FUENTE)
    seguro = ->(t) { ttf ? t.to_s : t.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8") }
    fecha = ->(t) { I18n.l(t, format: "%-d de %B de %Y") }
    logia = reunion.logia

    Prawn::Document.new(page_size: "A4", margin: 50, info: { Title: seguro.("Acta: #{reunion.titulo}"), Creator: "COMUNIA" }) do |d|
      if ttf
        d.font_families.update("DejaVu" => { normal: FUENTE, bold: FUENTE_NEGRITA })
        d.font "DejaVu"
      end
      seccion = ->(titulo) { d.move_down 12; d.text seguro.(titulo), size: 12, style: :bold; d.move_down 4 }

      d.text seguro.("#{logia.t_reunion} · #{logia.nombre_display}"), size: 10
      d.text seguro.(reunion.titulo), size: 18, style: :bold
      d.text seguro.("#{I18n.l(reunion.inicio, format: '%A %-d de %B de %Y')}, de #{reunion.inicio.strftime('%H:%M')} a " \
                     "#{reunion.fin.strftime('%H:%M')}#{" · #{reunion.lugar}" if reunion.lugar.present?}"), size: 10
      estado = if reunion.acta_aprobada?
        "Acta aprobada el #{fecha.(reunion.acta_aprobada_at)}#{" en «#{reunion.acta_aprobada_en.titulo}»" if reunion.acta_aprobada_en}."
      elsif reunion.acta_publicada?
        "Acta publicada el #{fecha.(reunion.acta_publicada_at)}, pendiente de aprobar."
      else
        "BORRADOR: el acta aún no está publicada."
      end
      d.move_down 4
      d.text seguro.(estado), size: 10, style: :bold

      if reunion.orden_del_dia.present?
        seccion.("Orden del día")
        d.text seguro.(reunion.orden_del_dia), size: 10
      end

      asistentes = reunion.reunion_asistencias.includes(miembro: :user).map { _1.miembro.user.nombre_completo.to_s }.sort
      seccion.("Asistencia")
      d.text seguro.("#{asistentes.size} de #{reunion.convocados.count} convocados · quórum del #{reunion.quorum} %"), size: 10
      d.text seguro.(asistentes.join(", ")), size: 9 if asistentes.any?

      seccion.("Acta")
      d.text seguro.(reunion.acta.presence || "(Sin texto.)"), size: 10

      acuerdos = reunion.reunion_acuerdos.includes(responsable: :user).to_a
      if acuerdos.any?
        seccion.("Acuerdos")
        acuerdos.each_with_index do |a, i|
          detalle = [("se encarga #{a.responsable.user.nombre_completo}" if a.responsable),
                     ("para el #{fecha.(a.vence_el)}" if a.vence_el),
                     (a.cumplido? ? "cumplido el #{fecha.(a.cumplido_at)}" : "pendiente")].compact.join(" · ")
          d.text seguro.("#{i + 1}. #{a.texto}"), size: 10
          d.text seguro.(detalle), size: 8
          d.move_down 3
        end
      end

      votaciones = reunion.reunion_votaciones.cerrada.to_a
      if votaciones.any?
        seccion.("Votaciones")
        votaciones.each do |v|
          totales = v.totales
          d.text seguro.("#{v.pregunta}#{' (secreta)' if v.secreta?}"), size: 10, style: :bold
          d.text seguro.("#{v.aprobada? ? 'Aprobada' : 'No aprobada'}: #{totales['si']} sí, #{totales['no']} no, " \
                         "#{totales['abstencion']} abstenciones · participación del #{v.participacion} %"), size: 9
          unless v.secreta?
            v.reunion_votos.includes(miembro: :user).group_by(&:opcion).each do |opcion, votos|
              d.text seguro.("#{OPCIONES[opcion]}: #{votos.map { _1.miembro.user.nombre_completo.to_s }.sort.join(', ')}"), size: 8
            end
          end
          d.move_down 4
        end
      end

      d.number_pages seguro.("Generado por COMUNIA el #{fecha.(Time.current)} · página <page> de <total>"),
                     at: [d.bounds.left, -10], size: 7
    end.render
  end
end
