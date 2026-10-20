module Denuncias
  # Retiros (Ley 1581). Retirar = despublicar: se borran las copias públicas y se conserva el
  # original cifrado. Con UMBRAL_OCULTAR solicitudes pendientes, la publicación se oculta sola.
  module Retiro
    UMBRAL_OCULTAR = 5 # decisión de Héctor (se le había recomendado 3)

    module_function

    def retirar(reporte, tipo, detalle = {})
      Reporte.transaction do
        claves = reporte.evidencias.filter_map(&:clave_publica)
        reporte.evidencias.update_all(clave_publica: nil)
        reporte.update!(estado: "retirado")
        Custodia.registrar(reporte.id, tipo, detalle)
        claves.each { Almacen.borrar(_1) }
      end
    end

    def solicitar(reporte, motivo:, contacto:)
      Reporte.transaction do
        s = SolicitudRetiro.create!(id: SecureRandom.uuid, reporte_id: reporte.id, motivo: motivo, estado: "pendiente",
                                    creado_en: Cripto.hora_redondeada,
                                    contacto_cif: (Cripto.cifrar_b64(contacto) if contacto))
        Custodia.registrar(reporte.id, "retiro_solicitado", { solicitud: s.id })
        pendientes = reporte.solicitudes_retiro.pendientes.count
        if pendientes >= UMBRAL_OCULTAR && reporte.estado == "publicado"
          reporte.update!(estado: "oculto")
          Custodia.registrar(reporte.id, "ocultado_por_solicitudes", { pendientes: pendientes })
        end
        s
      end
    end

    def resolver(solicitud, aceptar:)
      reporte = solicitud.reporte
      solicitud.update!(estado: aceptar ? "aceptada" : "rechazada")
      if aceptar
        retirar(reporte, "retirado_por_operador", { solicitud: solicitud.id })
      else
        Custodia.registrar(reporte.id, "retiro_rechazado", { solicitud: solicitud.id })
      end
    end

    def retirar_por_operador(reporte)
      reporte.solicitudes_retiro.pendientes.update_all(estado: "aceptada")
      retirar(reporte, "retirado_por_operador")
    end

    def restaurar(reporte)
      Reporte.transaction do
        n = reporte.solicitudes_retiro.pendientes.update_all(estado: "rechazada")
        reporte.update!(estado: "publicado")
        Custodia.registrar(reporte.id, "restaurado_por_operador", { solicitudes_rechazadas: n })
      end
    end
  end
end
