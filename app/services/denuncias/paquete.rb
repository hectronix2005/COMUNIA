require "prawn"

module Denuncias
  # Paquete de remisión a una autoridad: PDF con los datos, el texto ORIGINAL sin filtrar, las fotos
  # originales con su SHA-256, la verificación del sello (que en el PDF sale siempre) y la cadena de
  # custodia verificada. Héctor lo descarga y lo envía a mano.
  module Paquete
    FUENTE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    FUENTE_NEGRITA = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    FUENTE_MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

    module_function

    # → [pdf (bytes), sha256]. Registra la remisión y el evento paquete_generado DESPUÉS (el PDF no
    # puede contener su propio hash).
    def generar(reporte, entidad)
      texto = reporte.texto_original_cif ? JSON.parse(Cripto.descifrar_b64(reporte.texto_original_cif)) : nil
      evidencias = reporte.evidencias.map do |e|
        cifrado = Almacen.leer(e.clave_original) or raise "falta el original de la evidencia #{e.id}"
        [e, Cripto.descifrar(cifrado)]
      end
      eventos = reporte.eventos.to_a
      pdf = componer(reporte, entidad, texto, evidencias, eventos, Custodia.verificar(eventos))
      sha = Cripto.sha256_hex(pdf)
      remision = Remision.create!(id: SecureRandom.uuid, reporte_id: reporte.id, entidad: entidad,
                                  paquete_sha256: sha, creado_en: Cripto.hora_redondeada)
      Custodia.registrar(reporte.id, "paquete_generado", { remision: remision.id, entidad: entidad, sha256: sha })
      [pdf, sha]
    end

    def componer(r, entidad, original, evidencias, eventos, verificacion)
      ttf = File.exist?(FUENTE)
      seguro = ->(t) { ttf ? t.to_s : t.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8") }
      t = original ? original.transform_keys(&:to_sym) : { titulo: r.titulo, descripcion: r.descripcion, lugar: r.lugar }

      Prawn::Document.new(page_size: "A4", margin: 50, info: { Title: "Remisión DENUNCIAPP #{r.id}", Creator: "COMUNIA · DENUNCIAPP" }) do |d|
        if ttf
          d.font_families.update("DejaVu" => { normal: FUENTE, bold: FUENTE_NEGRITA }, "Mono" => { normal: FUENTE_MONO })
          d.font "DejaVu"
        end
        mono = ttf ? "Mono" : "Courier"
        campo = ->(etiqueta, valor) { d.text seguro.(etiqueta), size: 9, style: :bold; d.text seguro.(valor), size: 10; d.move_down 4 }

        d.text "DENUNCIAPP · Paquete de remisión", size: 16, style: :bold
        d.text seguro.("Para: #{entidad}"), size: 11
        d.text "Generado: #{Time.now.utc.iso8601}", size: 9
        d.move_down 10
        d.text "Información aportada por un ciudadano a través de un portal ciudadano. No ha sido verificada por el operador.", size: 9
        d.move_down 10

        campo.("Identificador del reporte", r.id)
        campo.("Categoría", Catalogo::CATEGORIAS.fetch(r.categoria, r.categoria))
        campo.("Denunciante", r.cuenta&.alias ? "Alias @#{r.cuenta.alias} (identidad bajo reserva del operador)" : "Anónimo")
        campo.("Verificación", r.verificada ? "Denunciante verificado por una comunidad certificada. Lo acredita un pase anónimo de firma ciega (RFC 9474): el portal no conoce a la persona ni a su comunidad." : "Sin verificar.")
        campo.("Fecha de recepción (redondeada a la hora, UTC)", r.creado_en.utc.iso8601)
        campo.("Localidad / lugar", "#{r.localidad} · #{t[:lugar]}")
        campo.("Título", t[:titulo])
        campo.("Descripción", t[:descripcion])
        d.text "Texto original completo; en el muro público se ocultaron cédulas y teléfonos.", size: 8 if original
        campo.("Estado en el portal", r.estado)

        d.move_down 10
        d.text "Evidencias (#{evidencias.size})", size: 13, style: :bold
        evidencias.each do |e, bytes|
          d.move_down 6
          campo.("Foto #{e.orden + 1} · #{e.mime} · #{e.bytes} bytes", "SHA-256 del original:")
          d.font(mono) { d.text e.sha256_original, size: 8 }
          begin
            d.image StringIO.new(bytes), fit: [d.bounds.width, 300]
          rescue StandardError
            d.text "(La imagen no se pudo incrustar; se entrega el archivo original aparte.)", size: 8
          end
        end

        d.start_new_page
        d.text "Cadena de custodia", size: 13, style: :bold
        d.text(verificacion[:valida] ? "Verificada: #{verificacion[:eventos]} eventos encadenados por SHA-256, sin alteraciones." :
                 "ATENCIÓN: la cadena NO verifica (se rompe en el evento #{verificacion[:roto_en] + 1}).", style: :bold)
        d.text "Cada evento incluye el hash del anterior; el primero parte de 64 ceros.", size: 8
        d.move_down 6
        eventos.each_with_index do |ev, i|
          d.text seguro.("#{i + 1}. #{ev.creado_en} · #{ev.tipo}#{" · evidencia #{ev.evidencia_id}" if ev.evidencia_id}"), size: 9, style: :bold
          # Los JSON largos sin espacios se cortan por caracteres para no salirse del margen.
          d.font(mono) do
            d.text seguro.("detalle: #{ev.detalle_json}").scan(/.{1,90}/).join("\n"), size: 7
            d.text "hash: #{ev.hash_evento}", size: 7
          end
          d.move_down 3
        end
      end.render
    end
  end
end
