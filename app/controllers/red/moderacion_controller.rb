module Red
  # Moderación de la plataforma: certificar comunidades, resolver reportes, revisar publicaciones
  # retenidas y ver métricas. Solo moderadores (Red.moderador?); para los demás, no existe.
  class ModeracionController < BaseController
    before_action :exigir_moderador

    def index
      @comunidades = Comunidad.pendientes.includes(:solicitada_por).order(:created_at)
      @reportes = Reporte.pendientes.includes(:objeto).order(:created_at).limit(100)
      @retenidas = Publicacion.where(estado: "en_revision").includes(user: :red_perfil).order(:updated_at).limit(100)
      @logias = Logia.where.not(id: Comunidad.where.not(logia_id: nil).select(:logia_id)).ordenadas.limit(200)
      @alertas = Red::Alertas.crecimiento_anomalo
    end

    def comunidad
      c = Comunidad.find_by(token: params[:token].to_s) or return no_encontrado
      if params[:accion] == "certificar"
        c.certificar!(por: current_user)
      else
        motivo = texto(:motivo, 500)
        return redirect_to(red_moderacion_path, alert: "Escribe el motivo.") if motivo.blank?
        c.cambiar_estado!({ "rechazar" => "rechazada", "suspender" => "suspendida", "revocar" => "revocada" }.fetch(params[:accion]),
                          por: current_user, motivo: motivo)
      end
      avisar(c.solicitada_por, "Tu comunidad #{c.nombre}: #{c.estado}", c.motivo_estado, red_comunidad_path(c)) if c.solicitada_por
      redirect_to red_moderacion_path, notice: "#{c.nombre}: #{c.estado}."
    end

    def reporte
      r = Reporte.pendientes.find_by(id: params[:id].to_i) or return no_encontrado
      iguales = Reporte.pendientes.where(objeto: r.objeto)
      Reporte.transaction do
        if params[:accion] == "sancionar"
          retirar(r.objeto)
          r.responsable&.red_perfil&.sancionar!
          iguales.update_all(estado: "sancionado", resuelto_por_id: current_user.id, resuelto_at: Time.current)
        else
          iguales.update_all(estado: "descartado", resuelto_por_id: current_user.id, resuelto_at: Time.current)
          restaurar(r.objeto)
        end
      end
      redirect_to red_moderacion_path, notice: "Reporte resuelto."
    end

    def aprobar
      p = Publicacion.find_by(token: params[:token].to_s, estado: "en_revision") or return no_encontrado
      p.update!(estado: "activa", motivo_revision: nil)
      Reporte.pendientes.where(objeto: p).update_all(estado: "descartado", resuelto_por_id: current_user.id, resuelto_at: Time.current)
      avisar(p.user, "Tu publicación ya está visible", p.titulo, red_publicacion_path(p))
      redirect_to red_moderacion_path, notice: "Publicación aprobada."
    end

    def certificar_logia
      logia = Logia.find_by(id: params[:id].to_i) or return no_encontrado
      c = CertificarLogia.call(logia, por: current_user)
      redirect_to red_moderacion_path, notice: "#{c.nombre} certificada con #{c.miembros_count} miembros."
    end

    def metricas
      @m = {
        cuentas_red: User.where(solo_red: true).count,
        perfiles: Perfil.count, publicos: Perfil.buscables_sin_cuenta.count,
        comunidades: Comunidad.certificadas.count, pendientes: Comunidad.pendientes.count,
        membresias: Membresia.vigentes.count,
        publicaciones: Publicacion.vigentes.count,
        necesito: Publicacion.vigentes.where(intencion: "necesito").count,
        ofrezco: Publicacion.vigentes.where(intencion: "ofrezco").count,
        conversaciones_30: Conversacion.where("created_at >= ?", 30.days.ago).count,
        resenas: Resena.count, reportes_pendientes: Reporte.pendientes.count,
        niveles: Confianza.group(:nivel).count
      }
      @busquedas = BusquedaDiaria.where("fecha >= ?", 30.days.ago.to_date).order(:fecha)
    end

    private

    def retirar(objeto)
      case objeto
      when Publicacion then objeto.update!(estado: "retirada", motivo_revision: "Retirada por moderación")
      when Mensaje then objeto.update!(cuerpo: "[Mensaje retirado por moderación]")
      end
    end

    def restaurar(objeto)
      objeto.update!(estado: "activa", motivo_revision: nil) if objeto.is_a?(Publicacion) && objeto.estado == "en_revision"
    end

    def avisar(user, titulo, cuerpo, url)
      NotificacionService.crear!(user: user, tipo: "red_moderacion", titulo: titulo, cuerpo: cuerpo, url: url)
    rescue StandardError => e
      Rails.logger.warn("[red] aviso de moderación: #{e.class}")
    end
  end
end
