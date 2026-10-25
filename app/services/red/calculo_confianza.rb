module Red
  # Fórmula de confianza. Crece con el número y el tamaño de las comunidades que avalan a la persona, con
  # rendimientos decrecientes y defensas contra comunidades falsas, infladas o colusivas.
  #
  #   aporte(c) = tamaño × solidez × antigüedad × anillo
  #     tamaño     = min(1, log10(n) / 4)        n = miembros verificados (10.000 → 1; 100 → 0,5)
  #     solidez    = min(1, días certificada / 180)   y 0 si n < 5
  #     antigüedad = min(1, días de la membresía / 30)  (inflar de golpe no sirve)
  #     anillo     = 0,25 si quien la avaló fue avalado por la persona (A↔B o A→C→B→A)
  #   Dos comunidades con más del 80 % de miembros en común cuentan como una (la de más aporte).
  #   puntaje = Σ aporte_i × 0,7^i, con los aportes de mayor a menor (tope 1 por comunidad)
  #   × 0,5 por cada sanción de moderación.
  #   nivel: 0 sin comunidades · 1 Básico · 2 ≥ 0,35 · 3 ≥ 0,8 · 4 ≥ 1,4
  #
  # Se recalcula en lote una vez al día (Red::RecalcularConfianzaJob): así un cambio de nivel no
  # coincide con el momento en que la persona entra en otra comunidad.
  module CalculoConfianza
    MADUREZ_COMUNIDAD = 180.0 # días
    MADUREZ_MEMBRESIA = 30.0
    DECAIMIENTO = 0.7
    FACTOR_ANILLO = 0.25
    SOLAPE_DUPLICADA = 0.8
    UMBRALES = { 4 => 1.4, 3 => 0.8, 2 => 0.35 }.freeze

    # Lo que se carga una vez por lote: miembros de cada comunidad y el grafo de avales.
    class Contexto
      attr_reader :ahora

      def initialize(ahora = Time.current)
        @ahora = ahora
        filas = Membresia.vigentes.pluck(:comunidad_id, :user_id, :verificada_por_id)
        @miembros = Hash.new { |h, k| h[k] = Set.new }
        @avalo = Hash.new { |h, k| h[k] = Set.new } # verificador → personas que avaló
        filas.each do |comunidad_id, user_id, por|
          @miembros[comunidad_id] << user_id
          @avalo[por] << user_id if por
        end
        @solapes = {}
      end

      def tamano(comunidad_id) = @miembros[comunidad_id].size

      # ¿`por` (quien avaló a `persona`) fue avalado por ella, directamente o con un intermediario?
      def anillo?(persona, por)
        return false if por.nil?
        avalados = @avalo[persona]
        avalados.include?(por) || avalados.any? { |intermedio| @avalo[intermedio].include?(por) }
      end

      def duplicadas?(a, b)
        clave = [a, b].minmax
        @solapes.fetch(clave) do
          ma, mb = @miembros[a], @miembros[b]
          union = (ma | mb).size
          @solapes[clave] = union.positive? && (ma & mb).size.fdiv(union) > SOLAPE_DUPLICADA
        end
      end
    end

    module_function

    def calcular(user, contexto = Contexto.new)
      perfil = user.red_perfil
      ahora = contexto.ahora
      aportes = Membresia.vigentes.where(user_id: user.id).includes(:comunidad).filter_map do |m|
        c = m.comunidad
        n = contexto.tamano(c.id)
        next if n < Comunidad::MINIMO_MIEMBROS
        tamano = [Math.log10(n) / 4.0, 1.0].min
        solidez = [dias(ahora, c.certificada_at) / MADUREZ_COMUNIDAD, 1.0].min
        antiguedad = [dias(ahora, m.verificada_at) / MADUREZ_MEMBRESIA, 1.0].min
        anillo = contexto.anillo?(user.id, m.verificada_por_id) ? FACTOR_ANILLO : 1.0
        { comunidad_id: c.id, n: n, aporte: tamano * solidez * antiguedad * anillo }
      end

      contadas = []
      aportes.sort_by { -_1[:aporte] }.each do |a|
        contadas << a unless contadas.any? { contexto.duplicadas?(_1[:comunidad_id], a[:comunidad_id]) }
      end

      puntaje = contadas.each_with_index.sum { |a, i| a[:aporte] * DECAIMIENTO**i }
      puntaje *= 0.5**perfil.sanciones if perfil
      nivel = if contadas.empty? || perfil&.suspendido? then 0
              else UMBRALES.find { |_, minimo| puntaje >= minimo }&.first || 1
              end
      { puntaje: puntaje.round(4), nivel: nivel, comunidades: contadas.size, miembros: contadas.sum { _1[:n] } }
    end

    def guardar!(user, contexto = Contexto.new)
      r = calcular(user, contexto)
      fila = Confianza.find_or_initialize_by(user_id: user.id)
      fila.update!(puntaje: r[:puntaje], nivel: r[:nivel], comunidades: r[:comunidades],
                   banda_miembros: Red.banda(r[:miembros]), calculada_at: contexto.ahora)
      fila
    end

    # El lote diario: todas las personas con perfil o con alguna membresía, y la foto del tamaño de
    # cada comunidad (lo que se enseña de ella, en banda).
    def recalcular_todo!(ahora = Time.current)
      contexto = Contexto.new(ahora)
      Comunidad.find_each { |c| c.update_column(:tamano_publico, c.certificada? ? contexto.tamano(c.id) : 0) }
      ids = (Perfil.pluck(:user_id) + Membresia.distinct.pluck(:user_id)).uniq
      User.where(id: ids).find_each { |u| guardar!(u, contexto) }
    end

    def dias(ahora, desde) = desde ? [(ahora - desde) / 1.day, 0].max : 0
  end
end
