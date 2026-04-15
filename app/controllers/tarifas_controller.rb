class TarifasController < ApplicationController
  before_action :set_logia
  before_action :set_tarifa, only: [:edit, :update, :destroy]

  def index
    authorize @logia, :show?
    @tarifas = @logia.tarifas.ordenadas
    @tarifa_actual = @logia.tarifa_vigente
    @conceptos = @logia.conceptos_cobro.activos.ordenados
    @monto_mensual_actual = @logia.monto_mensual
  end

  def new
    authorize @logia, :gestionar_conceptos?
    @tarifa = @logia.tarifas.build(
      vigente_desde: Date.current.beginning_of_month,
      vigente_hasta: Date.current.end_of_month,
      monto: @logia.monto_mensual
    )
    @conceptos = @logia.conceptos_cobro.activos.ordenados
  end

  def create
    authorize @logia, :gestionar_conceptos?
    @tarifa = @logia.tarifas.build(tarifa_params)
    @tarifa.creado_por = current_user
    @tarifa.desglose = Tarifa.snapshot_desglose(@logia)

    if @tarifa.save
      redirect_to logia_tarifas_path(@logia), notice: "Tarifa registrada. Vigente #{@tarifa.rango_texto}."
    else
      @conceptos = @logia.conceptos_cobro.activos.ordenados
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @logia, :gestionar_conceptos?
    @conceptos = @logia.conceptos_cobro.activos.ordenados
  end

  def update
    authorize @logia, :gestionar_conceptos?

    if @tarifa.update(tarifa_params)
      redirect_to logia_tarifas_path(@logia), notice: "Tarifa actualizada. Vigente #{@tarifa.rango_texto}."
    else
      @conceptos = @logia.conceptos_cobro.activos.ordenados
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @logia, :gestionar_conceptos?
    @tarifa.destroy
    redirect_to logia_tarifas_path(@logia), notice: "Tarifa eliminada."
  end

  private

  def set_logia
    @logia = Logia.find(params[:logia_id])
  end

  def set_tarifa
    @tarifa = @logia.tarifas.find(params[:id])
  end

  def tarifa_params
    params.require(:tarifa).permit(:monto, :vigente_desde, :vigente_hasta)
  end
end
