module Denuncias
  # Panel del operador de DENUNCIAPP, en el host de COMUNIA y SOLO para el superadmin (nunca para los
  # admins de logia). Aquí sí hay sesión de COMUNIA: es la del operador, no la de quien denuncia.
  class AdminController < ::ApplicationController
    before_action :solo_superadmin

    def index
      @pendientes = SolicitudRetiro.pendientes.includes(:reporte).order(:creado_en)
      @ocultos = Reporte.where(estado: "oculto").order(n: :desc)
      @recientes = Reporte.publicados.order(n: :desc).limit(50)
      @recompensas = Recompensa.order(creado_en: :desc).limit(50)
    end

    def resolver_retiro
      s = SolicitudRetiro.find_by(id: params[:id].to_s, estado: "pendiente") or return head(:not_found)
      Retiro.resolver(s, aceptar: params[:decision] == "aceptar")
      redirect_to denuncias_admin_path, notice: "Solicitud resuelta."
    end

    def retirar
      r = Reporte.find_by(id: params[:id].to_s)
      return head(:not_found) if r.nil? || r.estado == "retirado"
      Retiro.retirar_por_operador(r)
      redirect_to denuncias_admin_path, notice: "Publicación retirada."
    end

    def restaurar
      r = Reporte.find_by(id: params[:id].to_s, estado: "oculto") or return head(:not_found)
      Retiro.restaurar(r)
      redirect_to denuncias_admin_path, notice: "Publicación restaurada."
    end

    def custodia
      @reporte = Reporte.find_by(id: params[:id].to_s) or return head(:not_found)
      @eventos = @reporte.eventos.to_a
      @verificacion = Custodia.verificar(@eventos)
    end

    # Original descifrado, para entregarlo a una autoridad. Queda registrado en la custodia.
    def original
      e = Evidencia.find_by(id: params[:id].to_s) or return head(:not_found)
      cifrado = Almacen.leer(e.clave_original) or return head(:not_found)
      Custodia.registrar(e.reporte_id, "original_descifrado", { sha256: e.sha256_original }, evidencia_id: e.id)
      send_data Cripto.descifrar(cifrado), type: e.mime, disposition: "attachment", filename: "#{e.sha256_original}.#{e.extension}"
    end

    def paquete
      r = Reporte.find_by(id: params[:id].to_s) or return head(:not_found)
      entidad = params[:entidad].is_a?(String) ? params[:entidad].strip : ""
      return render(plain: "Indica la entidad destino (3 a 120 caracteres)", status: :bad_request) unless entidad.length.between?(3, 120)
      pdf, = Paquete.generar(r, entidad)
      send_data pdf, type: "application/pdf", disposition: "attachment", filename: "remision-#{r.id}.pdf"
    end

    def crear_recompensa
      campo = ->(k, max) { params[k].is_a?(String) ? params[k].strip[0, max] : "" }
      fuente = campo.(:fuente_url, 500)
      if [campo.(:titulo, 200), campo.(:entidad, 120), campo.(:monto_texto, 120)].any?(&:blank?) || !fuente.start_with?("https://")
        return redirect_to(denuncias_admin_path, alert: "Datos incompletos; la fuente debe ser https")
      end
      vigente = campo.(:vigente_hasta, 10)
      Recompensa.create!(id: SecureRandom.uuid, titulo: campo.(:titulo, 200), entidad: campo.(:entidad, 120),
                         monto_texto: campo.(:monto_texto, 120), fuente_url: fuente,
                         vigente_hasta: (Date.iso8601(vigente) rescue nil), estado: "publicada",
                         creado_en: Cripto.hora_redondeada)
      redirect_to denuncias_admin_path, notice: "Recompensa publicada."
    end

    def vencer_recompensa
      Recompensa.where(id: params[:id].to_s).update_all(estado: "vencida")
      redirect_to denuncias_admin_path, notice: "Recompensa marcada como vencida."
    end

    private

    def solo_superadmin
      redirect_to root_path, alert: "Acceso denegado." unless current_user&.rol_ref&.es_super_admin?
    end
  end
end
