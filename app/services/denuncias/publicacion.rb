module Denuncias
  # POST /api/reportes, en el mismo orden que DENUNCIAPP (traspaso, 2.2): se valida TODO antes de
  # escribir nada. Ni la IP ni ningún dato de la sesión de COMUNIA llegan aquí.
  class Publicacion
    Error = Class.new(StandardError) # mensaje para el ciudadano, siempre 400

    Resultado = Data.define(:id, :codigo, :sello, :sello_publico)

    def initialize(params, cuenta: nil, mismo_origen: false, pases: Pases.almacen_global)
      @p = params
      @cuenta = cuenta
      @mismo_origen = mismo_origen
      @pases = pases
    end

    def call
      raise Error, "Captcha no válido" unless Captcha.valido?(@p["cf-turnstile-response"])
      raise Error, "Debes aceptar los términos" unless @p["acepto_terminos"] == "si"

      # Por defecto, anónimo aunque haya sesión. Con alias solo si se pide.
      cuenta_id = nil
      if @p["publicar_como"] == "alias"
        raise Error, "Para publicar con tu alias, entra y elige uno" unless @cuenta&.alias && @mismo_origen
        cuenta_id = @cuenta.id
      end

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

      # Pase de COMUNIA: inválido → la denuncia entra igual, sin sello.
      sello = nil
      pase_hash = nil
      if @p["pase"].present?
        pase_hash = Pases.verificar(@p["pase"], @pases)
        sello = "pase_invalido" unless pase_hash
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
      codigo = Cripto.codigo_seguimiento
      creado_en = Cripto.hora_redondeada
      escritos = []

      Reporte.transaction do
        sello = PaseUsado.marcar(pase_hash) ? "aplicado" : "pase_usado" if pase_hash
        verificada = sello == "aplicado"
        @sello_publico = verificada && @pases.sello_publico?

        Reporte.create!(
          id:, categoria:, localidad:, recompensa_id:, cuenta_id:, verificada:, sello_publico: @sello_publico,
          creado_en:, estado: "publicado",
          titulo: filtrados[:titulo].first, descripcion: filtrados[:descripcion].first, lugar: filtrados[:lugar].first,
          codigo_hash: Cripto.sha256_hex(Cripto.normalizar_codigo(codigo)),
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
                           { categoria:, fotos: preparadas.size, con_alias: cuenta_id.present?, verificada: })
      end

      Resultado.new(id:, codigo:, sello:, sello_publico: @sello_publico)
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
