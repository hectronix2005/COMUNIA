module Denuncias
  # Cadena de custodia: cada evento lleva el hash del anterior; alterar o borrar uno rompe la cadena.
  # hash = sha256(hash_prev | reporte_id | evidencia_id | tipo | detalle_json | creado_en).
  # detalle_json y creado_en se guardan como TEXTO y el hash va sobre ese texto exacto (una
  # columna jsonb reordenaría las claves y la cadena dejaría de verificar).
  module Custodia
    GENESIS = ("0" * 64).freeze

    module_function

    def hash_evento(e)
      Cripto.sha256_hex([e.hash_prev, e.reporte_id, e.evidencia_id.to_s, e.tipo, e.detalle_json, e.creado_en].join("|"))
    end

    def registrar(reporte_id, tipo, detalle = {}, evidencia_id: nil)
      EventoCustodia.transaction do
        # Bloqueo por reporte para que dos eventos simultáneos no partan del mismo hash previo.
        EventoCustodia.connection.execute(
          EventoCustodia.sanitize_sql(["SELECT pg_advisory_xact_lock(hashtext(?))", "custodia/#{reporte_id}"])
        )
        previo = EventoCustodia.where(reporte_id: reporte_id).order(:n).last&.hash_evento || GENESIS
        e = EventoCustodia.new(reporte_id: reporte_id, evidencia_id: evidencia_id, tipo: tipo,
                               detalle_json: detalle.to_json, hash_prev: previo,
                               creado_en: Cripto.hora_redondeada.iso8601(3))
        e.hash_evento = hash_evento(e)
        e.save!
        e
      end
    end

    # → { valida: true, eventos: n } o { valida: false, roto_en: i }
    def verificar(eventos)
      previo = GENESIS
      eventos.each_with_index do |e, i|
        return { valida: false, roto_en: i } if e.hash_prev != previo || hash_evento(e) != e.hash_evento
        previo = e.hash_evento
      end
      { valida: true, eventos: eventos.size }
    end
  end
end
