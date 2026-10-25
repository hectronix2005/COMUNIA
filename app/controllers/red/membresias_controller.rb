module Red
  # Pertenecer a una comunidad: pedir entrar con evidencia, salir, ver el directorio de sus
  # miembros (solo para sus miembros verificados) y ver las mías (solo yo).
  class MembresiasController < BaseController
    before_action :exigir_perfil, only: :create
    before_action :cargar_comunidad, except: :mias

    MAX_PENDIENTES = 5

    def mias
      @membresias = current_user.red_membresias.includes(:comunidad).order(created_at: :desc)
    end

    def create
      mia = @comunidad.membresias.find_by(user_id: current_user.id)
      if mia&.estado.in?(%w[verificada solicitada])
        return redirect_to(red_comunidad_path(@comunidad), notice: "Ya pediste entrar o ya eres miembro.")
      end
      if current_user.red_membresias.pendientes.count >= MAX_PENDIENTES
        return redirect_to(red_comunidad_path(@comunidad), alert: "Tienes #{MAX_PENDIENTES} solicitudes pendientes. Espera a que las revisen.")
      end
      if @comunidad.metodo_verificacion == "correo_institucional" && !@comunidad.correo_admitido?(current_user.email)
        return redirect_to(red_comunidad_path(@comunidad), alert: "Esta comunidad pide una cuenta con correo @#{@comunidad.dominio_correo}.")
      end

      m = mia || @comunidad.membresias.new(user: current_user)
      m.assign_attributes(estado: "solicitada", rol: "miembro", evidencia: texto(:evidencia, 1000), motivo: nil,
                          verificada_por: nil, verificada_at: nil, vence_el: nil)
      if m.save
        avisar_verificadores
        redirect_to red_comunidad_path(@comunidad), notice: "Solicitud enviada a los verificadores de #{@comunidad.nombre}."
      else
        redirect_to red_comunidad_path(@comunidad), alert: m.errors.full_messages.to_sentence
      end
    end

    def destroy
      m = @comunidad.membresias.find_by(user_id: current_user.id)
      m&.update!(estado: "retirada", rol: "miembro", motivo: "Salió por su cuenta")
      redirect_to red_mis_comunidades_path, notice: "Saliste de #{@comunidad.nombre}."
    end

    # Directorio de la comunidad: solo para sus miembros verificados. Cada ficha enseña lo de siempre
    # (nivel, número de comunidades en total); nunca cuáles son las otras.
    def index
      return no_encontrado unless @comunidad.membresias.verificadas_y_vigentes.exists?(user_id: current_user.id) || moderador?
      ids = @comunidad.membresias.verificadas_y_vigentes.select(:user_id)
      @perfiles = Perfil.activos.where(user_id: ids).order(:nombre_publico).page(params[:page]).per(50)
      @fichas = Ficha.de_lista(@perfiles.to_a)
    end

    private

    def cargar_comunidad
      @comunidad = Comunidad.certificadas.find_by(token: params[:token].to_s) or no_encontrado
    end

    def avisar_verificadores
      ids = @comunidad.membresias.verificadas_y_vigentes.where(rol: %w[verificador administrador]).pluck(:user_id)
      User.where(id: ids).find_each do |v|
        NotificacionService.crear!(user: v, tipo: "red_membresia", titulo: "Nueva solicitud en #{@comunidad.nombre}",
                                   url: gestion_red_comunidad_path(@comunidad))
      end
    rescue StandardError => e
      Rails.logger.warn("[red] aviso a verificadores: #{e.class}")
    end
  end
end
