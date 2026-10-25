module Red
  # Lote diario de la red (config/recurring.yml, 4 a. m.):
  # 0. sincroniza las logias certificadas con su registro (altas, bajas y renovación de la membresía);
  # 1. recalcula la foto de confianza de todos a la vez, para que un cambio de nivel no delate en qué
  #    momento alguien entró en otra comunidad;
  # 2. borra el contacto que dejaron quienes escribieron sin cuenta hace más de 90 días (Ley 1581,
  #    finalidad cumplida);
  # 3. avisa de lo que está por vencer: publicaciones (3 días) y membresías (15 días).
  class MantenimientoDiarioJob < ApplicationJob
    queue_as :default

    def perform(ahora = Time.current)
      sincronizar_logias
      CalculoConfianza.recalcular_todo!(ahora)
      purgar_contactos_externos(ahora)
      avisar_vencimientos(ahora.to_date)
    end

    private

    # Una logia no tiene verificadores en la red: su registro en COMUNIA es la evidencia.
    def sincronizar_logias
      Comunidad.where(estado: "certificada").where.not(logia_id: nil).includes(:logia, :revisada_por).find_each do |c|
        Comunidad.transaction { CertificarLogia.sincronizar!(c, c.logia, c.revisada_por) }
      rescue StandardError => e
        Rails.logger.warn("[red] logia #{c.logia_id} sin sincronizar: #{e.class}")
      end
    end

    def purgar_contactos_externos(ahora)
      Conversacion.where(iniciador_id: nil).where.not(contacto_externo_cif: nil)
                  .where(created_at: ...(ahora - Conversacion::RETENCION_EXTERNA))
                  .update_all(contacto_externo_cif: nil, updated_at: ahora)
    end

    def avisar_vencimientos(hoy)
      Publicacion.where(estado: "activa", vence_el: hoy + 3).includes(:user).find_each do |p|
        avisar(p.user, "Tu publicación vence en 3 días", "«#{p.titulo}». Renuévala si sigue en pie.",
               Rails.application.routes.url_helpers.red_publicacion_path(p))
      end
      Membresia.where(estado: "verificada", vence_el: hoy + 15).includes(:comunidad, :user).find_each do |m|
        avisar(m.user, "Tu membresía en #{m.comunidad.nombre} vence en 15 días",
               "Pide a un verificador de la comunidad que la renueve.", Rails.application.routes.url_helpers.red_mis_comunidades_path)
      end
    end

    def avisar(user, titulo, cuerpo, url)
      NotificacionService.crear!(user: user, tipo: "red_aviso", titulo: titulo, cuerpo: cuerpo, url: url)
    rescue StandardError => e
      Rails.logger.warn("[red] aviso no enviado: #{e.class}")
    end
  end
end
