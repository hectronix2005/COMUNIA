module Denuncias
  # El muro (público), denunciar y «Mis denuncias». Denuncian solo los miembros activos, con su sesión
  # de COMUNIA: la denuncia queda ligada a su usuario, pero en el muro no se dice quién fue.
  class ReportesController < BaseController
    POR_PAGINA = 20

    before_action :authenticate_user!, only: %i[new create mias retirar]
    before_action :exigir_ficha_activa, only: %i[new create]

    def index
      antes = Integer(params[:antes], exception: false)
      lista = Reporte.publicados.includes(:evidencias).order(n: :desc).limit(POR_PAGINA + 1)
      lista = lista.where(n: ...antes) if antes&.positive?
      @reportes = lista.to_a
      if @reportes.size > POR_PAGINA
        @reportes.pop
        @mas = @reportes.last.n
      end
      @recompensas = antes ? [] : Recompensa.publicadas.to_a
    end

    def new
      @valores = { "recompensa_id" => params[:recompensa].to_s }
      @valores["categoria"] = "ubicacion_buscado" if Recompensa.publicadas.exists?(id: @valores["recompensa_id"])
    end

    def create
      return redirect_to(denuncias_muro_path, alert: "El módulo aún no recibe denuncias.") unless disponible?
      return volver_al_formulario("Has publicado demasiadas denuncias; espera una hora.", :too_many_requests) unless limite?(:reporte, "u#{current_user.id}")
      if request.content_length.to_i > Catalogo::MAX_FOTOS * Catalogo::MAX_BYTES_FOTO + 1.megabyte
        return volver_al_formulario("Las fotos pesan demasiado.", :payload_too_large)
      end

      Publicacion.new(params_reporte, user: current_user, verificada: current_miembro&.activo? || false).call
      redirect_to denuncias_mias_path, notice: "Tu denuncia está publicada en el muro."
    rescue Publicacion::Error => e
      volver_al_formulario(e.message)
    end

    def mias
      @reportes = Reporte.where(user: current_user).includes(:evidencias).order(n: :desc)
    end

    def retirar
      reporte = Reporte.where(user: current_user).where.not(estado: "retirado").find_by(id: params[:id].to_s)
      return redirect_to(denuncias_mias_path, alert: "No se encontró esa denuncia.") unless reporte
      Retiro.retirar(reporte, "retirado_por_autor")
      redirect_to denuncias_mias_path, notice: "Retirada: ya no sale en el muro."
    end

    # Copia pública (sin EXIF) de una foto de una denuncia publicada.
    def foto
      clave = "publicas/#{params[:archivo]}"
      e = (Evidencia.joins(:reporte).find_by(clave_publica: clave, reporte: { estado: "publicado" }) if Almacen::CLAVE_VALIDA.match?(clave))
      datos = e && Almacen.leer(clave)
      return head(:not_found) unless datos
      expires_in 5.minutes, public: true
      send_data datos, type: e.mime, disposition: :inline
    end

    private

    def exigir_ficha_activa
      return if current_miembro&.activo?
      redirect_to denuncias_muro_path, alert: "Para denunciar tienes que ser miembro activo de una comunidad de COMUNIA."
    end

    # Lista blanca de lo que se lee del formulario: escalares y, en fotos[]/hashes[], listas.
    def params_reporte
      datos = params.permit(:categoria, :localidad, :titulo, :descripcion, :lugar, :recompensa_id, :acepto_terminos,
                            fotos: [], hashes: []).to_h
      datos["fotos"] = Array(datos["fotos"]).compact_blank # el campo oculto de los file_field múltiples llega vacío
      datos
    end

    def volver_al_formulario(error, estado = :unprocessable_content)
      @error = error
      @valores = params_reporte.except("fotos", "hashes").transform_values(&:to_s)
      render :new, status: estado
    end
  end
end
