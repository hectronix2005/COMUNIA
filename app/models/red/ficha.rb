module Red
  # Lo único que los demás ven de una persona: su perfil y la foto de su confianza (nivel, cuántas
  # comunidades y una banda de miembros). No lee red_membresias, así que no puede decir cuáles son.
  class Ficha
    CAMPOS_JSON = %w[token nombre_publico titular ciudad nivel nivel_texto comunidades banda_miembros
                     resenas promedio miembro_desde].freeze

    attr_reader :perfil

    def initialize(perfil, confianza: nil, resumen: nil)
      @perfil = perfil
      @confianza = confianza
      @resumen = resumen
    end

    # Para listas: una consulta de confianzas y otra de reseñas para todas las fichas.
    def self.de_lista(perfiles)
      ids = perfiles.map(&:user_id)
      confianzas = Confianza.where(user_id: ids).index_by(&:user_id)
      resumenes = Resena.where(sujeto_id: ids).group(:sujeto_id).pluck(:sujeto_id, Arel.sql("COUNT(*)"), Arel.sql("AVG(puntaje)"))
                        .to_h { |id, n, prom| [id, { total: n, promedio: prom.to_f.round(1) }] }
      perfiles.to_h do |p|
        [p.user_id, new(p, confianza: confianzas[p.user_id] || Confianza.de(p.user), resumen: resumenes[p.user_id] || { total: 0, promedio: nil })]
      end
    end

    delegate :token, :nombre_publico, :titular, :ciudad, :bio, :habilidades, to: :perfil

    def confianza = @confianza ||= Confianza.de(perfil.user)

    def resumen = @resumen ||= Resena.resumen_de(perfil.user)

    def nivel = confianza.nivel

    def nivel_texto = confianza.nivel_texto

    def comunidades = confianza.comunidades

    def banda_miembros = confianza.banda_miembros

    def certificacion_texto
      return "Aún sin comunidades certificadas" if comunidades.zero?
      "#{comunidades} #{comunidades == 1 ? 'comunidad certificada' : 'comunidades certificadas'} · " \
        "#{BANDAS.fetch(banda_miembros)} en total"
    end

    def resenas = resumen[:total]

    def promedio = resumen[:promedio]

    def miembro_desde = I18n.l(perfil.created_at.to_date, format: "%B de %Y")

    def as_json(*)
      { "token" => token, "nombre_publico" => nombre_publico, "titular" => titular, "ciudad" => ciudad,
        "nivel" => nivel, "nivel_texto" => nivel_texto, "comunidades" => comunidades,
        "banda_miembros" => BANDAS.fetch(banda_miembros), "resenas" => resenas, "promedio" => promedio,
        "miembro_desde" => miembro_desde }
    end
  end
end
