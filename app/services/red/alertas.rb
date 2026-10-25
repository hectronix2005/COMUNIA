module Red
  # Señales de comunidades infladas para la moderación (la fórmula ya las frena; esto avisa).
  module Alertas
    CRECIMIENTO_MINIMO = 20     # altas en 7 días
    CRECIMIENTO_RELATIVO = 0.5  # respecto de los miembros de hace 7 días
    APROBACIONES_DIA = 30       # aprobaciones de un mismo verificador en 24 h

    module_function

    def crecimiento_anomalo(ahora = Time.current)
      altas = Membresia.where(estado: "verificada").where(verificada_at: (ahora - 7.days)..ahora).group(:comunidad_id).count
      comunidades = Comunidad.where(id: altas.keys).index_by(&:id)
      por_crecimiento = altas.filter_map do |id, n|
        c = comunidades[id]
        antes = [c.miembros_count - n, 0].max
        next unless n >= CRECIMIENTO_MINIMO && (antes.zero? || n.fdiv(antes) >= CRECIMIENTO_RELATIVO)
        { comunidad: c, texto: "#{n} altas en 7 días (tenía #{antes})" }
      end

      rapidos = Membresia.where(verificada_at: (ahora - 1.day)..ahora).where.not(verificada_por_id: nil)
                         .group(:comunidad_id, :verificada_por_id).having("COUNT(*) >= ?", APROBACIONES_DIA).count
      por_verificador = rapidos.map do |(cid, _por), n|
        { comunidad: Comunidad.find(cid), texto: "un verificador aprobó #{n} membresías en 24 h" }
      end
      por_crecimiento + por_verificador
    end
  end
end
