module Red
  # Visibilidad por alcance, común a perfiles y publicaciones (ambos tienen user_id y alcance).
  #
  # `visibles_para(viewer)` arma SIEMPRE una sola consulta, con la misma forma para lo oculto y para lo
  # que no existe: así un 404 no se distingue de otro ni por el cuerpo ni por las consultas ni por el
  # tiempo. Solo mira las comunidades de quien mira, nunca enseña las del autor.
  module ConAlcance
    extend ActiveSupport::Concern

    ALCANCES = {
      "mis_comunidades" => "Solo mis comunidades",
      "elegidas" => "Solo las comunidades que yo elija",
      "publico" => "Todas las comunidades y la búsqueda pública, con mi nivel de confianza"
    }.freeze

    included do
      has_many :alcances, as: :objeto, class_name: "Red::Alcance", dependent: :delete_all
      validates :alcance, inclusion: { in: ALCANCES.keys }
      validate :comunidades_elegidas_validas
    end

    class_methods do
      # El autor está verificado y vigente en alguna de las comunidades :ids (las de quien mira).
      def autor_comparte_sql
        <<~SQL.squish
          EXISTS (
            SELECT 1 FROM red_membresias m JOIN red_comunidades c ON c.id = m.comunidad_id
            WHERE m.user_id = #{table_name}.user_id AND m.comunidad_id IN (:ids) AND m.estado = 'verificada'
              AND (m.vence_el IS NULL OR m.vence_el >= CURRENT_DATE) AND c.estado = 'certificada')
        SQL
      end

      def visibles_para(viewer, comunidad_ids = Red.comunidades_de(viewer))
        t = table_name
        tipo = name
        condiciones = ["#{t}.alcance = 'publico'"]
        binds = {}
        if viewer
          condiciones << "#{t}.user_id = :viewer"
          binds[:viewer] = viewer.id
        end
        if comunidad_ids.any?
          binds[:ids] = comunidad_ids
          condiciones << "(#{t}.alcance = 'mis_comunidades' AND #{autor_comparte_sql})"
          # Elegida por el autor, y el autor sigue verificado en ella.
          binds[:tipo] = tipo
          condiciones << <<~SQL.squish
            (#{t}.alcance = 'elegidas' AND EXISTS (
              SELECT 1 FROM red_alcances a
              JOIN red_membresias m ON m.comunidad_id = a.comunidad_id AND m.user_id = #{t}.user_id
              JOIN red_comunidades c ON c.id = a.comunidad_id
              WHERE a.objeto_type = :tipo AND a.objeto_id = #{t}.id AND a.comunidad_id IN (:ids)
                AND m.estado = 'verificada' AND (m.vence_el IS NULL OR m.vence_el >= CURRENT_DATE)
                AND c.estado = 'certificada'))
          SQL
        end
        where(sanitize_sql_array(["(#{condiciones.join(' OR ')})", binds]))
      end
    end

    def alcance_texto = ALCANCES.fetch(alcance)

    def comunidad_ids_elegidas = alcances.map(&:comunidad_id)

    # Fija las comunidades elegidas. Solo valen las del autor; las demás se descartan sin decir nada
    # (un error distinto diría que la comunidad existe).
    def comunidades_elegidas=(ids)
      propias = Red.comunidades_de(user)
      elegidas = Array(ids).map(&:to_i) & propias
      @comunidades_elegidas_cambiadas = true
      alcances.reset if persisted?
      self.alcances = elegidas.map { |id| alcances.find { _1.comunidad_id == id } || Alcance.new(comunidad_id: id) }
    end

    private

    def comunidades_elegidas_validas
      return unless alcance == "elegidas"
      errors.add(:alcance, "elige al menos una de tus comunidades") if alcances.reject(&:marked_for_destruction?).empty?
    end
  end
end
