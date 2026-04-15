class ConceptosCobroController < ApplicationController
  before_action :require_tesorero!
  before_action :set_logia
  before_action :set_concepto, only: [:edit, :update, :destroy]

  def index
    authorize @logia, :show?
    @conceptos = @logia.conceptos_cobro.ordenados
    @total_mensual = @logia.monto_mensual
    @miembros_activos = @logia.miembros.activos.includes(:user).joins(:user).order("users.apellido ASC, users.nombre ASC")

    # Evolución mensual: 6 meses atrás + mes actual + 2 meses adelante
    @evolucion_mensual = []
    fecha = 6.months.ago.beginning_of_month
    fin = 2.months.from_now.beginning_of_month
    while fecha <= fin
      conteo = @logia.miembros_cobrables_count_en(fecha)
      tarifa = @logia.tarifa_vigente(fecha)
      cuota_calculada = @logia.monto_mensual_para_conteo(conteo)
      @evolucion_mensual << {
        fecha:            fecha,
        conteo:           conteo,
        tarifa:           tarifa,
        cuota_calculada:  cuota_calculada,
        cuota_cobrada:    tarifa ? tarifa.monto : cuota_calculada
      }
      fecha = fecha.next_month
    end
  end

  def new
    @concepto = @logia.conceptos_cobro.build
    authorize_concepto
  end

  def create
    @concepto = @logia.conceptos_cobro.build(concepto_params)
    authorize_concepto

    if @concepto.save
      redirect_to logia_conceptos_cobro_path(@logia), notice: "Concepto creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize_concepto
  end

  def update
    authorize_concepto
    if @concepto.update(concepto_params)
      redirect_to logia_conceptos_cobro_path(@logia), notice: "Concepto actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_concepto
    @concepto.destroy
    redirect_to logia_conceptos_cobro_path(@logia), notice: "Concepto eliminado."
  end

  private

  def set_logia
    @logia = Logia.find(params[:logia_id])
  end

  def set_concepto
    @concepto = @logia.conceptos_cobro.find(params[:id])
  end

  def authorize_concepto
    authorize @logia, :gestionar_conceptos?
  end

  def concepto_params
    params.require(:concepto_cobro).permit(:nombre, :monto, :tipo, :descripcion, :activo, :orden)
  end
end
