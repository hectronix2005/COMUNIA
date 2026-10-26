module Denuncias
  # Publicar una denuncia, en el mismo orden que DENUNCIAPP (traspaso, 2.2): se valida TODO antes de
  # escribir nada. La denuncia queda ligada a quien la publica (user); en el muro no se muestra.
  class Publicacion
    Error = Class.new(StandardError) # mensaje para quien denuncia

    def initialize(params, user:, verificada:)
      @p = params
      @user = user
      @verificada = verificada
    end

    # Devuelve el id de la denuncia publicada.
    def call
      raise Error, "Debes aceptar los términos" unless @p["acepto_terminos"] == "si"

      categoria, localidad = @p["categoria"], @p["localidad"]
      originales = { titulo: texto(@p["titulo"], 5, 120), descripcion: texto(@p["descripcion"], 10, 3000),
                     lugar: texto(@p["lugar"], 3, 200) }
      unless Catalogo.categoria?(categoria) && Catalogo.localidad?(localidad) && originales.values.all?
        raise Error, "Datos incompletos o no válidos"
      end

      # Cédulas y teléfonos no salen al muro; el texto original queda cifrado como evidencia.
      filtrados = originales.transform_values { Filtro.ocultar(_1) }
      datos_ocultos = filtrados.values.sum(&:last)

      recompensa_id = nil
      if categoria == "ubicacion_buscado"
        r = Recompensa.find_by(id: @p["recompensa_id"].to_s, estado: "publicada") if @p["recompensa_id"].is_a?(String)
        raise Error, "Elige una recompensa oficial vigente" unless r
        recompensa_id = r.id
      end

      fotos, hashes = lista(@p["fotos"]), lista(@p["hashes"])
      unless fotos.size.between?(1, Catalogo::MAX_FOTOS) && hashes.size == fotos.size
        raise Error, "Adjunta entre 1 y #{Catalogo::MAX_FOTOS} fotos"
      end

      preparadas = fotos.each_with_index.map do |foto, i|
        raise Error, "Foto vacía o demasiado grande" unless foto.respond_to?(:read) && foto.size.between?(1, Catalogo::MAX_BYTES_FOTO)
        original = foto.read.b
        sha = Cripto.sha256_hex(original)
        raise Error, "La foto llegó alterada; vuelve a intentarlo" unless hashes[i] == sha
        mime, limpia, metadatos = Exif.limpiar(original)
        { original:, sha:, mime:, limpia:, metadatos: }
      rescue Exif::FormatoNoAdmitido
        raise Error, "Solo se admiten fotos JPEG o PNG"
      end

      id = SecureRandom.uuid
      creado_en = Cripto.hora_redondeada
      escritos = []

      Reporte.transaction do
        Reporte.create!(
          id:, categoria:, localidad:, recompensa_id:, user: @user, verificada: @verificada,
          creado_en:, estado: "publicado",
          titulo: filtrados[:titulo].first, descripcion: filtrados[:descripcion].first, lugar: filtrados[:lugar].first,
          texto_original_cif: (Cripto.cifrar_b64(originales.to_json) if datos_ocultos.positive?)
        )
        Custodia.registrar(id, "datos_ocultados", { cantidad: datos_ocultos }) if datos_ocultos.positive?

        preparadas.each_with_index do |p, orden|
          ev_id = SecureRandom.uuid
          clave_original = "originales/#{id}/#{ev_id}.bin"
          clave_publica = "publicas/#{ev_id}.#{p[:mime] == 'image/png' ? 'png' : 'jpg'}"
          Almacen.guardar(clave_original, Cripto.cifrar(p[:original]))
          escritos << clave_original
          Almacen.guardar(clave_publica, p[:limpia])
          escritos << clave_publica
          Evidencia.create!(id: ev_id, reporte_id: id, orden:, sha256_original: p[:sha], mime: p[:mime],
                            bytes: p[:original].bytesize, clave_original:, clave_publica:, creado_en:,
                            metadatos_cif: (Base64.strict_encode64(Cripto.cifrar(p[:metadatos])) unless p[:metadatos].empty?))
          Custodia.registrar(id, "evidencia_recibida",
                             { sha256: p[:sha], bytes: p[:original].bytesize, mime: p[:mime], metadatos_retirados: p[:metadatos].bytesize },
                             evidencia_id: ev_id)
        end
        Custodia.registrar(id, "reporte_publicado",
                           { categoria:, fotos: preparadas.size, verificada: @verificada })
      end

      id
    rescue Error
      raise
    rescue StandardError
      Array(escritos).each { Almacen.borrar(_1) } # la transacción se deshizo: sin archivos huérfanos
      raise
    end

    private

    def texto(v, min, max)
      return nil unless v.is_a?(String)
      t = v.strip
      t if t.length.between?(min, max)
    end

    def lista(v) = v.nil? ? [] : Array(v)
  end
end
