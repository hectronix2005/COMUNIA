module Red
  # Comunidades: el directorio público de las certificadas y la solicitud de una nueva.
  # De una comunidad se enseña qué la une, cómo comprueba a sus miembros y su tamaño en banda;
  # nunca quiénes son (eso solo lo ven sus miembros verificados, en Membresias#index).
  class ComunidadesController < BaseController
    publico only: %i[index show]
    before_action :exigir_perfil, only: %i[new create]

    POR_PAGINA = 24

    def index
      @q = texto(:q, 80)
      @tipo = Comunidad::TIPOS.key?(params[:tipo]) ? params[:tipo] : nil
      scope = Comunidad.certificadas
      scope = scope.where("red_comunidades.nombre ILIKE ?", "%#{Comunidad.sanitize_sql_like(@q)}%") if @q.present?
      scope = scope.where(tipo_vinculo: @tipo) if @tipo
      @comunidades = scope.order(:nombre).page(params[:page]).per(POR_PAGINA)
    end

    def show
      @comunidad = Comunidad.certificadas.find_by(token: params[:token].to_s)
      # Quien la pidió (o la plataforma) también la ve mientras está en revisión.
      @comunidad ||= Comunidad.find_by(token: params[:token].to_s, solicitada_por_id: current_user.id) if current_user
      @comunidad ||= Comunidad.find_by(token: params[:token].to_s) if moderador?
      return no_encontrado unless @comunidad
      @mia = current_user && @comunidad.membresias.find_by(user_id: current_user.id)
    end

    def new
      @comunidad = Comunidad.new(tipo_vinculo: "club", metodo_verificacion: "documento")
    end

    def create
      if Comunidad.where(solicitada_por: current_user, estado: "solicitada").count >= 3
        return redirect_to(red_mis_comunidades_path, alert: "Ya tienes 3 solicitudes en revisión. Espera a que las revisemos.")
      end

      @comunidad = Comunidad.new(datos_comunidad.merge(solicitada_por: current_user, estado: "solicitada"))
      Comunidad.transaction do
        @comunidad.save!
        @comunidad.membresias.create!(user: current_user, estado: "solicitada", rol: "administrador",
                                      evidencia: "Solicitó la comunidad")
      end
      avisar_moderadores
      redirect_to red_comunidad_path(@comunidad), notice: "Solicitud enviada. La revisamos y te avisamos."
    rescue ActiveRecord::RecordInvalid
      flash.now[:alert] = @comunidad.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end

    private

    def datos_comunidad
      { nombre: texto(:nombre, 80), tipo_vinculo: texto(:tipo_vinculo, 20), criterio: texto(:criterio, 500),
        descripcion: texto(:descripcion, 2000), ciudad: texto(:ciudad, 60), evidencia: texto(:evidencia, 2000),
        metodo_verificacion: texto(:metodo_verificacion, 30), dominio_correo: texto(:dominio_correo, 80)&.downcase.presence }
    end

    def avisar_moderadores
      User.joins(:rol_ref).where(roles: { codigo: "super_admin" }).find_each do |m|
        NotificacionService.crear!(user: m, tipo: "red_comunidad", titulo: "Nueva comunidad por certificar",
                                   cuerpo: @comunidad.nombre, url: red_moderacion_path)
      end
    rescue StandardError => e
      Rails.logger.warn("[red] aviso a moderadores: #{e.class}")
    end
  end
end
