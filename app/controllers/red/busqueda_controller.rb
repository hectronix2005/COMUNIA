module Red
  # Búsqueda sin cuenta (y con ella, que además ve lo de sus comunidades). Privacidad:
  # - Sin cuenta solo salen las publicaciones públicas y los perfiles que eligieron aparecer.
  # - El orden usa solo datos públicos: el nivel de la foto diaria y la fecha.
  # - El filtro por comunidad solo vale para las comunidades de quien busca; con otra se ignora, y la
  #   respuesta es la misma que sin filtro (no dice si la comunidad existe).
  # - El JSON sale de una lista blanca de campos (Red::Ficha::CAMPOS_JSON y CAMPOS_PUBLICACION).
  class BusquedaController < BaseController
    publico only: :index
    fuera_de_buscadores only: :index
    helper_method :pagina_url

    POR_PAGINA = 20
    PAGINAS_MAX = 25 # más allá no se sirve: frena a quien quiera copiarse todo el directorio
    CAMPOS_PUBLICACION = %w[token intencion categoria titulo descripcion ciudad modalidad precio_texto publicada_el].freeze
    # El nivel sale de la foto diaria (red_confianzas): es público y no depende de qué comunidades son.
    NIVEL = {
      "red_publicaciones" => ["LEFT JOIN red_confianzas rc ON rc.user_id = red_publicaciones.user_id",
                              "COALESCE(rc.nivel, 0) DESC, red_publicaciones.created_at DESC, red_publicaciones.id DESC"],
      "red_perfiles" => ["LEFT JOIN red_confianzas rc ON rc.user_id = red_perfiles.user_id",
                         "COALESCE(rc.nivel, 0) DESC, red_perfiles.created_at DESC, red_perfiles.id DESC"]
    }.freeze

    def index
      @filtros = filtros
      @que = @filtros[:que]
      @pagina = [[params[:page].to_i, 1].max, PAGINAS_MAX].min
      @resultados = @que == "personas" ? buscar_personas : buscar_publicaciones
      @fichas = Ficha.de_lista(@que == "personas" ? @resultados : @resultados.map { _1.user.red_perfil })
      BusquedaDiaria.contar!(con_cuenta: user_signed_in?) if params[:q].present? || params[:categoria].present?
      respond_to do |f|
        f.html
        f.json { render json: { que: @que, pagina: @pagina, resultados: @resultados.map { a_json(_1) } } }
      end
    end

    private

    def filtros
      {
        que: texto(:que, 20) == "personas" ? "personas" : "publicaciones",
        q: texto(:q, 100).presence,
        intencion: texto(:intencion, 10).presence_in(Publicacion::INTENCIONES.keys),
        categoria: texto(:categoria, 20).presence_in(Publicacion::CATEGORIAS.keys),
        modalidad: texto(:modalidad, 20).presence_in(Publicacion::MODALIDADES.keys),
        ciudad: texto(:ciudad, 60).presence,
        nivel_min: texto(:nivel_min, 1).to_i.clamp(0, 4),
        # Solo las de quien busca; un token ajeno o inventado da nil, igual que no filtrar.
        comunidad_id: (Comunidad.where(id: mis_comunidad_ids).find_by(token: texto(:comunidad, 30))&.id if mis_comunidad_ids.any? && texto(:comunidad, 30).present?)
      }
    end

    def con_nivel(relacion, tabla)
      union, orden = NIVEL.fetch(tabla)
      relacion.joins(union).where("COALESCE(rc.nivel, 0) >= ?", @filtros[:nivel_min]).reorder(Arel.sql(orden))
    end

    def buscar_publicaciones
      r = Publicacion.tablon_para(current_user, mis_comunidad_ids)
      if (q = @filtros[:q])
        r = r.where("red_publicaciones.titulo ILIKE :q OR red_publicaciones.descripcion ILIKE :q", q: "%#{Publicacion.sanitize_sql_like(q)}%")
      end
      r = r.where(intencion: @filtros[:intencion]) if @filtros[:intencion]
      r = r.where(categoria: @filtros[:categoria]) if @filtros[:categoria]
      r = r.where(modalidad: @filtros[:modalidad]) if @filtros[:modalidad]
      r = r.where("red_publicaciones.ciudad ILIKE ?", "#{Publicacion.sanitize_sql_like(@filtros[:ciudad])}%") if @filtros[:ciudad]
      r = r.where(Publicacion.sanitize_sql_array([Publicacion.autor_comparte_sql, { ids: [@filtros[:comunidad_id]] }])) if @filtros[:comunidad_id]
      con_nivel(r, "red_publicaciones").includes(user: :red_perfil).offset((@pagina - 1) * POR_PAGINA).limit(POR_PAGINA).to_a
    end

    def buscar_personas
      r = current_user ? Perfil.visibles_para(current_user, mis_comunidad_ids).activos : Perfil.buscables_sin_cuenta
      r = r.where.not(user_id: current_user.id) if current_user
      if (q = @filtros[:q])
        r = r.where("red_perfiles.nombre_publico ILIKE :q OR red_perfiles.titular ILIKE :q OR red_perfiles.habilidades ILIKE :q",
                    q: "%#{Perfil.sanitize_sql_like(q)}%")
      end
      r = r.where("red_perfiles.ciudad ILIKE ?", "#{Perfil.sanitize_sql_like(@filtros[:ciudad])}%") if @filtros[:ciudad]
      r = r.where(Perfil.sanitize_sql_array([Perfil.autor_comparte_sql, { ids: [@filtros[:comunidad_id]] }])) if @filtros[:comunidad_id]
      con_nivel(r, "red_perfiles").includes(:user).offset((@pagina - 1) * POR_PAGINA).limit(POR_PAGINA).to_a
    end

    # Enlaces de paginación armados solo con los filtros ya validados (nunca con params crudos).
    def pagina_url(pagina)
      f = @filtros
      red_buscar_path({ que: @que, q: f[:q], intencion: f[:intencion], categoria: f[:categoria], modalidad: f[:modalidad],
                        ciudad: f[:ciudad], nivel_min: (f[:nivel_min] if f[:nivel_min].positive?),
                        comunidad: (Comunidad.find(f[:comunidad_id]).token if f[:comunidad_id]), page: pagina }.compact)
    end

    def a_json(objeto)
      if objeto.is_a?(Perfil)
        @fichas.fetch(objeto.user_id).as_json
      else
        { "token" => objeto.token, "intencion" => objeto.intencion, "categoria" => objeto.categoria, "titulo" => objeto.titulo,
          "descripcion" => objeto.descripcion.truncate(300), "ciudad" => objeto.ciudad, "modalidad" => objeto.modalidad,
          "precio_texto" => objeto.precio_texto, "publicada_el" => objeto.created_at.to_date.iso8601,
          "autor" => @fichas.fetch(objeto.user_id).as_json }
      end
    end
  end
end
