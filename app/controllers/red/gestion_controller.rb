require "csv"

module Red
  # Panel de una comunidad para sus verificadores y administradores: solicitudes con su evidencia,
  # miembros, roles, métricas y exportación. Todo lo de aquí es de ESTA comunidad: ninguna consulta
  # mira las demás comunidades de sus miembros.
  class GestionController < BaseController
    before_action :cargar_comunidad
    before_action :exigir_administrador, only: %i[update exportar]

    ACCIONES_ADMIN = %w[revocar hacer_verificador hacer_miembro].freeze

    def show
      @pendientes = @comunidad.membresias.pendientes.includes(user: :red_perfil).order(:created_at)
      @miembros = @comunidad.membresias.where(estado: "verificada").includes(user: :red_perfil)
                            .order(Arel.sql("CASE rol WHEN 'administrador' THEN 0 WHEN 'verificador' THEN 1 ELSE 2 END"), :verificada_at)
                            .page(params[:page]).per(50)
      @metricas = metricas
    end

    def update
      if @comunidad.update(descripcion: texto(:descripcion, 2000), ciudad: texto(:ciudad, 60))
        redirect_to gestion_red_comunidad_path(@comunidad), notice: "Datos de la comunidad guardados."
      else
        redirect_to gestion_red_comunidad_path(@comunidad), alert: @comunidad.errors.full_messages.to_sentence
      end
    end

    # aprobar | rechazar | renovar (verificadores) · revocar | hacer_verificador | hacer_miembro (administradores).
    def decidir
      accion = params[:accion].to_s
      return no_encontrado if accion.in?(ACCIONES_ADMIN) && !@comunidad.administrador?(current_user)
      # Una sola consulta, dentro de ESTA comunidad: un perfil ajeno y uno inexistente responden igual.
      m = @comunidad.membresias.joins(user: :red_perfil).find_by(red_perfiles: { token: params[:perfil].to_s }) or return no_encontrado
      return volver("No puedes decidir sobre tu propia membresía.") if m.user_id == current_user.id && !moderador?

      motivo = texto(:motivo, 500)
      case accion
      when "aprobar"
        return volver("Esa solicitud ya no está pendiente.") unless m.estado == "solicitada"
        m.verificar!(por: current_user)
        avisar(m, "Te verificaron en #{@comunidad.nombre}")
      when "rechazar"
        return volver("Esa solicitud ya no está pendiente.") unless m.estado == "solicitada"
        m.rechazar!(motivo: motivo)
        avisar(m, "No se aprobó tu solicitud en #{@comunidad.nombre}", motivo)
      when "renovar"
        return volver("Solo se renuevan miembros verificados.") unless m.verificada?
        m.renovar!(por: current_user)
      when "revocar"
        return volver("Solo se revocan miembros verificados.") unless m.verificada?
        return volver("Escribe el motivo de la revocación.") if motivo.blank?
        return volver("La comunidad no puede quedarse sin administradores.") if ultimo_admin?(m)
        m.revocar!(motivo: motivo)
        avisar(m, "Se revocó tu membresía en #{@comunidad.nombre}", motivo)
      when "hacer_verificador", "hacer_miembro"
        return volver("Solo miembros verificados.") unless m.verificada?
        return volver("La comunidad no puede quedarse sin administradores.") if ultimo_admin?(m)
        m.update!(rol: accion == "hacer_verificador" ? "verificador" : "miembro")
      end
      redirect_to gestion_red_comunidad_path(@comunidad), notice: "Hecho."
    rescue ArgumentError => e
      volver(e.message)
    end

    # CSV de los miembros de esta comunidad, con lo que la comunidad ya sabe de ellos (su nombre en la red,
    # su rol y fechas aquí). Sin correos, teléfonos, nivel ni nada de otras comunidades.
    def exportar
      filas = @comunidad.membresias.includes(user: :red_perfil).order(:created_at)
      csv = CSV.generate(headers: true) do |out|
        out << ["Nombre en la red", "Estado", "Rol", "Verificada el", "Vence el"]
        filas.each do |m|
          out << [seguro_csv(m.user.red_perfil&.nombre_publico || m.user.nombre_corto), m.estado, m.rol_texto,
                  m.verificada_at&.to_date&.iso8601, m.vence_el&.iso8601]
        end
      end
      send_data csv, filename: "miembros-#{@comunidad.token[0, 6]}-#{Date.current.iso8601}.csv", type: "text/csv; charset=utf-8"
    end

    private

    def cargar_comunidad
      @comunidad = Comunidad.find_by(token: params[:token].to_s)
      no_encontrado unless @comunidad&.certificada? && @comunidad.verificador?(current_user)
    end

    def exigir_administrador
      no_encontrado unless @comunidad.administrador?(current_user)
    end

    def ultimo_admin?(m)
      m.rol == "administrador" && @comunidad.membresias.verificadas_y_vigentes.where(rol: "administrador").count <= 1
    end

    def volver(mensaje) = redirect_to(gestion_red_comunidad_path(@comunidad), alert: mensaje)

    def avisar(m, titulo, cuerpo = nil)
      NotificacionService.crear!(user: m.user, tipo: "red_membresia", titulo: titulo, cuerpo: cuerpo, url: red_mis_comunidades_path)
    rescue StandardError => e
      Rails.logger.warn("[red] aviso de membresía: #{e.class}")
    end

    # Evita que una hoja de cálculo ejecute una fórmula escrita como nombre.
    def seguro_csv(v) = v.to_s.start_with?("=", "+", "-", "@") ? "'#{v}" : v.to_s

    def metricas
      ms = @comunidad.membresias
      { verificados: ms.verificadas_y_vigentes.count, pendientes: ms.pendientes.count,
        nuevos_30: ms.verificadas_y_vigentes.where("verificada_at >= ?", 30.days.ago).count,
        por_vencer: ms.verificadas_y_vigentes.where(vence_el: Date.current..30.days.from_now.to_date).count,
        con_perfil: Perfil.where(user_id: ms.verificadas_y_vigentes.select(:user_id)).count,
        publicaciones: Publicacion.vigentes.where(user_id: ms.verificadas_y_vigentes.select(:user_id))
                                  .where(alcance: %w[mis_comunidades publico]).count }
    end
  end
end
