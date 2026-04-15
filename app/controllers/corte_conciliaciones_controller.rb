class CorteConciliacionesController < ApplicationController
  before_action :require_tesorero!
  before_action :set_logia
  before_action :set_corte, only: [:show, :destroy]

  def index
    authorize CorteConciliacion
    @cortes = policy_scope(CorteConciliacion)
               .where(logia_id: @logia.id)
               .recientes
               .page(params[:page])
  end

  def show
    authorize @corte
  end

  def create
    authorize CorteConciliacion

    @corte = CorteConciliacion.new(corte_params)
    @corte.logia      = @logia
    @corte.creado_por = current_user
    @corte.archivo.attach(params[:archivo]) if params[:archivo].present?

    # Auto-extraer fecha del Excel solo cuando el usuario no la indicó
    if @corte.fecha_corte.blank? && params[:archivo].present?
      @corte.fecha_corte = CorteConciliacionParser.extraer_fecha(params[:archivo])
    end

    if @corte.save
      CorteConciliacionParser.new(@corte).procesar!

      if @corte.error_parser?
        redirect_to corte_conciliaciones_path(logia_id: @logia.id),
                    alert: "Error al procesar el archivo: #{@corte.resultado['error']}"
      else
        redirect_to corte_conciliacion_path(@corte, logia_id: @logia.id),
                    notice: "Corte procesado y conciliado."
      end
    else
      redirect_to corte_conciliaciones_path(logia_id: @logia.id),
                  alert: @corte.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @corte
    @corte.archivo.purge_later if @corte.archivo.attached?
    @corte.destroy!
    redirect_to corte_conciliaciones_path(logia_id: @logia.id), notice: "Corte eliminado."
  end

  private

  def set_logia
    logia_id = params[:logia_id].presence || current_user.logia_id
    @logia   = logia_id ? Logia.find_by(id: logia_id) : Logia.ordenadas.first
    redirect_to root_path, alert: "No hay logias disponibles." unless @logia
  end

  def set_corte
    @corte = CorteConciliacion.find_by(id: params[:id])
    unless @corte && @corte.logia_id == @logia.id
      redirect_to corte_conciliaciones_path(logia_id: @logia.id), alert: "Corte no encontrado."
    end
  end

  def corte_params
    params.require(:corte_conciliacion).permit(:fecha_corte, :descripcion)
  end
end
