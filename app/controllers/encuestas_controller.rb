class EncuestasController < ApplicationController
  def index
    @encuestas = encuestas
                         .includes(:user, :logia, :encuesta_opciones)
                         .order(created_at: :desc)
                         .page(params[:page]).per(15)
  end

  def show
    @encuesta = encuestas.includes(encuesta_opciones: :encuesta_votos).find(params[:id])
    @total_votos = @encuesta.total_votos
    @ya_voto = @encuesta.usuario_voto?(current_user)
  end

  def new
    @encuesta = Encuesta.new
    3.times { @encuesta.encuesta_opciones.build }
  end

  def create
    @encuesta = Encuesta.new(encuesta_params)
    @encuesta.user = current_user
    @encuesta.logia = current_logia

    if @encuesta.save
      redirect_to encuesta_path(@encuesta), notice: "Encuesta creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def votar
    @encuesta = encuestas.find(params[:id])
    return redirect_to encuesta_path(@encuesta), alert: "Encuesta cerrada." if @encuesta.cerrada_o_expirada?
    return redirect_to encuesta_path(@encuesta), alert: "Ya votaste." if @encuesta.usuario_voto?(current_user)

    opcion_ids = Array(params[:opcion_ids]).map(&:to_i)
    opcion_ids = opcion_ids.first(1) unless @encuesta.multiple?

    opcion_ids.each do |oid|
      opcion = @encuesta.encuesta_opciones.find_by(id: oid)
      opcion.encuesta_votos.create!(user: current_user) if opcion
    end

    redirect_to encuesta_path(@encuesta), notice: "Voto registrado."
  end

  def cerrar
    @encuesta = encuestas.find(params[:id])
    return head(:forbidden) unless @encuesta.user_id == current_user.id || modera?(@encuesta)
    @encuesta.cerrada!
    redirect_to encuesta_path(@encuesta), notice: "Encuesta cerrada."
  end

  private

  def encuesta_params
    params.require(:encuesta).permit(
      :titulo, :descripcion, :anonima, :multiple, :cierre_en,
      encuesta_opciones_attributes: [:id, :texto, :posicion, :_destroy]
    )
  end

  def encuestas
    Encuesta.where(logia_id: logia_ids_visibles)
  end
end
