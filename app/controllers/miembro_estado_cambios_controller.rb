class MiembroEstadoCambiosController < ApplicationController
  before_action :set_miembro
  before_action :set_cambio

  def update
    authorize @miembro, :update?

    if @cambio.update(cambio_params)
      redirect_to edit_miembro_path(@miembro), notice: "Registro de historial actualizado."
    else
      redirect_to edit_miembro_path(@miembro),
                  alert: @cambio.errors.full_messages.join(", ")
    end
  end

  private

  def set_miembro
    @miembro = Miembro.find(params[:miembro_id])
  end

  def set_cambio
    @cambio = @miembro.estado_cambios.find(params[:id])
  end

  def cambio_params
    params.require(:miembro_estado_cambio).permit(:desde, :hasta, :motivo, :soporte)
  end
end
