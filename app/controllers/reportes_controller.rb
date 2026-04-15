class ReportesController < ApplicationController
  before_action :authorize_reportes

  def cartera
    @cobros = cobros_scope.pendiente.includes(:periodo_cobro, miembro: [:user, :logia])
    @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    @total = @cobros.sum(:monto)
    @logias = logias_para_filtro

    respond_to do |format|
      format.html { @cobros = @cobros.page(params[:page]) }
      format.xlsx { render xlsx: "cartera", filename: "cartera_#{Date.current}.xlsx" }
    end
  end

  def recaudacion
    @fecha_desde = params[:fecha_desde].present? ? Date.parse(params[:fecha_desde]) : Date.current.beginning_of_month
    @fecha_hasta = params[:fecha_hasta].present? ? Date.parse(params[:fecha_hasta]) : Date.current

    @pagos = Pago.validados
                 .where(validado_at: @fecha_desde.beginning_of_day..@fecha_hasta.end_of_day)
                 .includes(cobro: { miembro: [:user, :logia] })

    if params[:logia_id].present?
      @pagos = @pagos.joins(cobro: :miembro).where(miembros: { logia_id: params[:logia_id] })
    end

    if current_user.scope_propia_logia?
      @pagos = @pagos.joins(cobro: :miembro).where(miembros: { logia_id: current_user.logia_id })
    end

    @total = @pagos.sum(:monto_pagado)
    @logias = logias_para_filtro

    respond_to do |format|
      format.html { @pagos = @pagos.recientes.page(params[:page]) }
      format.xlsx { render xlsx: "recaudacion", filename: "recaudacion_#{@fecha_desde}_#{@fecha_hasta}.xlsx" }
    end
  end

  def morosos
    @cobros = cobros_scope.vencido.includes(:periodo_cobro, miembro: [:user, :logia])
    @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    @total = @cobros.sum(:monto)
    @logias = logias_para_filtro

    respond_to do |format|
      format.html { @cobros = @cobros.page(params[:page]) }
      format.xlsx { render xlsx: "morosos", filename: "morosos_#{Date.current}.xlsx" }
    end
  end

  def recibo
    @pago = Pago.find(params[:pago_id])
  end

  private

  def authorize_reportes
    authorize :reporte, "#{action_name}?"
  end

  def cobros_scope
    if current_user.scope_propia_logia?
      Cobro.por_logia(current_user.logia_id)
    else
      Cobro.all
    end
  end

  def logias_para_filtro
    current_user.tiene_permiso?("logias", "index") ? Logia.ordenadas : []
  end
end
