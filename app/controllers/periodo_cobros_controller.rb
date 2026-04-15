class PeriodoCobrosController < ApplicationController
  before_action :require_tesorero!
  before_action :set_periodo, only: [:show, :edit, :update, :destroy, :generar_cobros]

  def index
    authorize PeriodoCobro
    @periodos = policy_scope(PeriodoCobro).recientes.page(params[:page])

    if current_user.scope_propia_logia?
      @logia_actual = current_user.logia
    elsif current_user.tiene_permiso?("logias", "index")
      @logias_con_conceptos = Logia.includes(:conceptos_cobro, :tarifas).ordenadas
    end
  end

  def show
    authorize @periodo
    @cobros = @periodo.cobros.includes(miembro: [:user, :logia])

    if current_user.scope_propia_logia?
      @logia_actual = current_user.logia
      @conceptos = @logia_actual.conceptos_cobro.activos.ordenados
      @cobros = @cobros.por_logia(@logia_actual.id)
    elsif current_user.tiene_permiso?("logias", "index")
      @logias_con_conceptos = Logia.includes(:conceptos_cobro).ordenadas
      @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    end

    @cobros = @cobros.por_estado(params[:estado]) if params[:estado].present?
    @cobros = @cobros.page(params[:page])
  end

  def new
    @periodo = PeriodoCobro.new
    authorize @periodo
  end

  def create
    @periodo = PeriodoCobro.new(periodo_params)
    @periodo.creado_por = current_user
    authorize @periodo

    if @periodo.save
      redirect_to @periodo, notice: "Periodo de cobro creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @periodo
  end

  def update
    authorize @periodo

    # No permitir cambiar monto si hay cobros con pago (liquidados)
    if periodo_params[:monto].present? && periodo_params[:monto].to_f != @periodo.monto.to_f
      cobros_con_pago = @periodo.cobros.joins(:pago).count
      if cobros_con_pago > 0
        @periodo.errors.add(:monto, "no se puede modificar: hay #{cobros_con_pago} cobro(s) con pago asociado. Cree una nueva tarifa para cambios futuros.")
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @periodo.update(periodo_params)
      redirect_to @periodo, notice: "Periodo actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @periodo
    @periodo.destroy
    redirect_to periodo_cobros_path, notice: "Periodo eliminado exitosamente."
  end

  def generar_cobros
    authorize @periodo
    count_before = @periodo.cobros.count
    @periodo.generar_cobros!
    count_new = @periodo.cobros.count - count_before
    redirect_to @periodo, notice: "Se generaron #{count_new} cobros nuevos. Total: #{@periodo.cobros.count}."
  end

  private

  def set_periodo
    @periodo = PeriodoCobro.find(params[:id])
  end

  def periodo_params
    params.require(:periodo_cobro).permit(:anio, :mes, :monto, :fecha_vencimiento, :estado)
  end
end
