module Denuncias
  # API pública del muro. Ninguna acción registra IP, user-agent ni cabeceras del cliente.
  class ApiController < BaseController
    def config_publica
      render json: {
        categorias: Catalogo::CATEGORIAS, localidades: Catalogo::LOCALIDADES,
        maxFotos: Catalogo::MAX_FOTOS, maxBytesFoto: Catalogo::MAX_BYTES_FOTO,
        cuentas: Denuncias.cuentas?, selloPublico: Pases.almacen_global.sello_publico?,
        turnstileSiteKey: Denuncias.turnstile_site_key, contacto: Denuncias.contacto, disponible: disponible?
      }
    end

    def reportes
      antes = Integer(params[:antes], exception: false)
      lista = Reporte.publicados.includes(:evidencias, :cuenta).order(n: :desc).limit(20)
      lista = lista.where(n: ...antes) if antes&.positive?
      render json: lista.map(&:a_publico)
    end

    def recompensas
      render json: Recompensa.publicadas.map(&:a_publico)
    end

    def media
      clave = "publicas/#{params[:archivo]}"
      e = (Evidencia.joins(:reporte).find_by(clave_publica: clave, reporte: { estado: "publicado" }) if Almacen::CLAVE_VALIDA.match?(clave))
      datos = e && Almacen.leer(clave)
      return head(:not_found) unless datos
      expires_in 5.minutes, public: true
      send_data datos, type: e.mime, disposition: :inline
    end

    def crear_reporte
      return render(json: { error: "El módulo aún no recibe denuncias" }, status: :service_unavailable) unless disponible?
      return unless limite!(:reporte)
      if request.content_length.to_i > Catalogo::MAX_FOTOS * Catalogo::MAX_BYTES_FOTO + 1.megabyte
        return render(json: { error: "Demasiado grande" }, status: :payload_too_large)
      end

      r = Publicacion.new(params_reporte, cuenta: cuenta_actual, mismo_origen: mismo_origen?).call
      cuerpo = { id: r.id, codigo: r.codigo }
      cuerpo.merge!(sello: r.sello, selloPublico: r.sello_publico) if r.sello
      render json: cuerpo, status: :created
    rescue Publicacion::Error => e
      render json: { error: e.message }, status: :bad_request
    end

    def seguimiento
      return unless limite!(:seguimiento)
      limpio = Cripto.normalizar_codigo(params[:codigo].is_a?(String) ? params[:codigo] : "")
      reporte = Reporte.find_by(codigo_hash: Cripto.sha256_hex(limpio)) if limpio.length == 29
      return render(json: { error: "Código no encontrado" }, status: :not_found) unless reporte

      if params[:accion] == "retirar" && reporte.estado != "retirado"
        Retiro.retirar(reporte, "retirado_por_autor")
        return render(json: { id: reporte.id, estado: "retirado" })
      end
      render json: { id: reporte.id, estado: reporte.estado, titulo: reporte.titulo }
    end

    def solicitar_retiro
      return unless limite!(:retiro)
      return render(json: { error: "Captcha no válido" }, status: :bad_request) unless Captcha.valido?(params["cf-turnstile-response"])
      reporte = Reporte.find_by(id: params[:id].to_s, estado: "publicado")
      return render(json: { error: "No encontrado" }, status: :not_found) unless reporte
      return unless limite!(:retiro_reporte, "#{ip_efimera}|#{reporte.id}")

      motivo = texto(params[:motivo], 10, 2000)
      contacto = params[:contacto].presence && texto(params[:contacto], 3, 200)
      if motivo.nil? || (params[:contacto].present? && contacto.nil?)
        return render(json: { error: "Explica el motivo (mínimo 10 caracteres)" }, status: :bad_request)
      end
      Retiro.solicitar(reporte, motivo: motivo, contacto: contacto)
      render json: { ok: true }, status: :created
    end

    private

    # Lista blanca de lo que se lee del formulario: escalares y, en fotos[]/hashes[], listas.
    def params_reporte
      params.permit(:categoria, :localidad, :titulo, :descripcion, :lugar, :recompensa_id, :publicar_como,
                    :acepto_terminos, :"cf-turnstile-response", :pase, fotos: [], hashes: []).to_h
    end

    def texto(v, min, max)
      return nil unless v.is_a?(String)
      t = v.strip
      t if t.length.between?(min, max)
    end
  end
end
