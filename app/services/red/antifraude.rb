module Red
  # Reglas contra el abuso al publicar: topes por persona, palabras típicas de estafa y cuarentena de
  # las cuentas nuevas. No sustituye a la moderación; frena lo obvio y manda lo dudoso a revisión.
  module Antifraude
    ACTIVAS_MAX = 5
    ACTIVAS_MAX_NIVEL_ALTO = 10 # nivel ≥ 3
    POR_DIA_MAX = 3

    # Pedir dinero por adelantado, cambiar a otro canal o cobrar por un empleo: patrones de estafa
    # frecuentes en Colombia. Llevan la publicación a revisión, no la rechazan.
    SOSPECHOSAS = [
      /consign(a|e|ar)\s+(primero|antes|por adelantado)/i, /pago\s+(anticipado|por adelantado)/i,
      /\b(western union|moneygram|criptomoneda|bitcoin|usdt|binance)\b/i, /gana\s+\$?\d[\d.]*\s*(diarios|al d[ií]a)/i,
      /\btrabaj[ao] desde casa\b.*\b(inscripci[oó]n|matr[ií]cula)\b/i, /\bcostos? de (inscripci[oó]n|tr[aá]mite)\b/i,
      /\b(escr[ií]beme|cont[aá]ctame) (al|por) (whats?app|telegram)\b/i, /\bt\.me\//i, /wa\.me\//i,
      /\bc[oó]digo de verificaci[oó]n\b/i, /\bpr[eé]stamos? sin (estudio|requisitos)\b/i
    ].freeze

    module_function

    def limite_activas(user) = Confianza.de(user).nivel >= 3 ? ACTIVAS_MAX_NIVEL_ALTO : ACTIVAS_MAX

    # nil si puede publicar; si no, el motivo para la persona.
    def motivo_para_no_publicar(user, perfil)
      return "Tu cuenta está suspendida por moderación." if perfil.suspendido?
      return "Para publicar necesitas estar verificado en al menos una comunidad." if Red.comunidades_de(user).empty?
      activas = user.red_publicaciones.where(estado: %w[activa en_revision]).where("vence_el >= ?", Date.current).count
      return "Ya tienes #{activas} publicaciones activas: cierra o pausa alguna antes de crear otra." if activas >= limite_activas(user)
      return "Puedes crear hasta #{POR_DIA_MAX} publicaciones al día. Vuelve mañana." if
        user.red_publicaciones.where(created_at: 24.hours.ago..).count >= POR_DIA_MAX
      nil
    end

    def sospechosa?(*textos)
      texto = textos.compact.join(" ")
      SOSPECHOSAS.any? { texto.match?(_1) }
    end

    # Lo público de una cuenta nueva espera a que acabe la cuarentena (sus comunidades sí lo ven).
    def publica_desde(perfil) = [perfil.cuarentena_hasta, Time.current].max
  end
end
