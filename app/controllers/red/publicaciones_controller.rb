module Red
  # Tablón de necesito/ofrezco. Publicar exige perfil y estar verificado en alguna comunidad; los topes,
  # la cuarentena y el filtro de estafas están en Red::Antifraude.
  class PublicacionesController < BaseController
    publico only: :show
    fuera_de_buscadores only: :show

    before_action :exigir_perfil, except: :show
    before_action :cargar_propia, only: %i[edit update renovar cambiar_estado]

    # Cambios de estado que la persona puede hacer (en revisión y retirada solo los cambia moderación).
    TRANSICIONES = { "pausada" => %w[activa], "activa" => %w[pausada cerrada], "cerrada" => %w[activa] }.freeze

    def show
      token = params[:token].to_s
      @publicacion = current_user&.red_publicaciones&.find_by(token: token) ||
                     (moderador? && Publicacion.find_by(token: token)) ||
                     Publicacion.visible(token, current_user)
      return no_encontrado unless @publicacion
      @autor = @publicacion.user.red_perfil
      @ficha = Ficha.new(@autor)
      @propia = current_user && @publicacion.user_id == current_user.id
      @perfil_visible = current_user ? Perfil.visibles_para(current_user, mis_comunidad_ids).activos.exists?(id: @autor.id)
                                     : Perfil.buscables_sin_cuenta.exists?(id: @autor.id)
    end

    def mias
      @publicaciones = current_user.red_publicaciones.order(created_at: :desc).page(params[:page]).per(20)
    end

    def new
      @publicacion = Publicacion.new(intencion: texto(:intencion, 10).presence_in(Publicacion::INTENCIONES.keys) || "ofrezco",
                                     alcance: mi_perfil.alcance, modalidad: "presencial", ciudad: mi_perfil.ciudad)
      @bloqueo = Antifraude.motivo_para_no_publicar(current_user, mi_perfil)
    end

    def create
      @publicacion = current_user.red_publicaciones.new(datos)
      if (motivo = Antifraude.motivo_para_no_publicar(current_user, mi_perfil))
        return volver(:new, motivo)
      end
      aplicar_alcance
      revisar_y_poner_fecha
      return volver(:new, @publicacion.errors.full_messages.to_sentence) unless @publicacion.save
      redirect_to red_publicacion_path(@publicacion), notice: aviso_tras_guardar
    end

    def edit; end

    def update
      @publicacion.assign_attributes(datos)
      aplicar_alcance
      revisar_y_poner_fecha
      return volver(:edit, @publicacion.errors.full_messages.to_sentence) unless @publicacion.save
      redirect_to red_publicacion_path(@publicacion), notice: aviso_tras_guardar
    end

    def renovar
      return redirect_to(red_publicacion_path(@publicacion), alert: "Esta publicación no se puede renovar.") if
        %w[en_revision retirada].include?(@publicacion.estado)
      @publicacion.renovar!
      redirect_to red_publicacion_path(@publicacion), notice: "Renovada por #{Publicacion::VIGENCIA.in_days.to_i} días más."
    end

    def cambiar_estado
      nuevo = texto(:estado, 20)
      return redirect_to(red_publicacion_path(@publicacion), alert: "Ese cambio no está permitido.") unless
        TRANSICIONES.fetch(@publicacion.estado, []).include?(nuevo)
      @publicacion.update!(estado: nuevo)
      redirect_to red_publicacion_path(@publicacion), notice: "Publicación #{nuevo}."
    end

    private

    def cargar_propia
      @publicacion = current_user.red_publicaciones.find_by(token: params[:token].to_s)
      no_encontrado unless @publicacion
    end

    def datos
      { intencion: texto(:intencion, 10), categoria: texto(:categoria, 20), titulo: texto(:titulo, 100),
        descripcion: texto(:descripcion, 3000), ciudad: texto(:ciudad, 60), modalidad: texto(:modalidad, 20),
        precio_texto: texto(:precio_texto, 60) }.compact
    end

    def aplicar_alcance
      alcance = texto(:alcance, 20)
      @publicacion.alcance = alcance if ConAlcance::ALCANCES.key?(alcance)
      @publicacion.comunidades_elegidas = Array(params[:comunidades]).grep(String) if @publicacion.alcance == "elegidas"
    end

    # Lo sospechoso pasa a revisión; editar algo en revisión no lo saca de ella. Lo público de una
    # cuenta en cuarentena espera.
    def revisar_y_poner_fecha
      if Antifraude.sospechosa?(@publicacion.titulo, @publicacion.descripcion, @publicacion.precio_texto)
        @publicacion.estado = "en_revision"
        @publicacion.motivo_revision = "Filtro automático: patrón frecuente de estafa"
      end
      @publicacion.publica_desde = Antifraude.publica_desde(mi_perfil) if @publicacion.new_record? || @publicacion.alcance_changed?
    end

    def aviso_tras_guardar
      return "Quedó en revisión: un moderador la mirará antes de mostrarla." if @publicacion.estado == "en_revision"
      return "Publicada. Por ser cuenta nueva, fuera de tus comunidades se verá desde el #{I18n.l(@publicacion.publica_desde, format: :short)}." if
        @publicacion.alcance == "publico" && @publicacion.publica_desde > Time.current
      "Publicada."
    end

    def volver(vista, mensaje)
      flash.now[:alert] = mensaje
      @bloqueo = nil
      render vista, status: :unprocessable_content
    end
  end
end
