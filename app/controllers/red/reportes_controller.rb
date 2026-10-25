module Red
  # Reportes de publicaciones, perfiles y mensajes. Un voto por persona (o por IP, con HMAC, sin
  # guardarla). Con Reporte::OCULTAR_CON votos pendientes, una publicación pasa a revisión hasta que
  # moderación decide. La respuesta es siempre la misma, exista o no lo reportado.
  class ReportesController < BaseController
    publico only: :create

    TIPOS = { "publicacion" => "Red::Publicacion", "perfil" => "Red::Perfil", "mensaje" => "Red::Mensaje" }.freeze

    def create
      return gracias unless user_signed_in? || (captcha_disponible? && captcha_valido?)
      objeto = buscar_objeto
      motivo = texto(:motivo, 30)
      if objeto && Reporte::MOTIVOS.key?(motivo) && objeto.try(:user_id) != current_user&.id
        huella = current_user ? "u:#{current_user.id}" : Cifra.huella_ip(request.remote_ip)
        reporte = Reporte.new(objeto: objeto, reportante: current_user, huella: huella, motivo: motivo, detalle: texto(:detalle, 1000))
        aplicar_umbral(objeto) if reporte.save
      end
      gracias
    end

    private

    # Solo se puede reportar lo que uno puede ver.
    def buscar_objeto
      token = texto(:token, 30).to_s
      case texto(:tipo, 20)
      when "publicacion" then Publicacion.visible(token, current_user)
      when "perfil"
        (current_user ? Perfil.visibles_para(current_user, mis_comunidad_ids).activos : Perfil.buscables_sin_cuenta).find_by(token: token)
      when "mensaje"
        return unless current_user
        m = Mensaje.find_by(id: token.to_i)
        m if m&.conversacion&.participa?(current_user)
      end
    end

    def aplicar_umbral(objeto)
      pendientes = Reporte.pendientes.where(objeto: objeto).count
      objeto.update_column(:reportes_count, pendientes) if objeto.is_a?(Publicacion)
      return unless pendientes == Reporte::OCULTAR_CON
      objeto.update!(estado: "en_revision", motivo_revision: "#{pendientes} reportes de personas distintas") if objeto.is_a?(Publicacion) && objeto.estado == "activa"
      Red.moderadores.find_each { |m| Red.avisar(m, "Contenido con #{pendientes} reportes", nil, red_moderacion_path, tipo: "red_moderacion") }
    end

    def gracias
      redirect_back fallback_location: red_inicio_path, notice: "Gracias. Moderación lo revisará."
    end
  end
end
