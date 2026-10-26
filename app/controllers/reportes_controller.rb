class ReportesController < ApplicationController
  before_action :authorize_reportes

  def cartera
    @cobros = cobros_scope.pendiente.includes(:periodo_cobro, miembro: [:user, :logia])
    @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    @total = @cobros.sum(:monto)
    @logias = logias_tesoreria

    respond_to do |format|
      format.html { @cobros = @cobros.page(params[:page]) }
      format.xlsx { render xlsx: "cartera", filename: "cartera_#{Date.current}.xlsx" }
    end
  end

  def recaudacion
    @fecha_desde = fecha_param(:fecha_desde) || Date.current.beginning_of_month
    @fecha_hasta = fecha_param(:fecha_hasta) || Date.current

    @pagos = Pago.validados
                 .where(validado_at: @fecha_desde.beginning_of_day..@fecha_hasta.end_of_day)
                 .includes(cobro: { miembro: [:user, :logia] })

    if params[:logia_id].present?
      @pagos = @pagos.joins(cobro: :miembro).where(miembros: { logia_id: params[:logia_id] })
    end

    if (ids = logia_ids_tesoreria)
      @pagos = @pagos.joins(cobro: :miembro).where(miembros: { logia_id: ids })
    end

    @total = @pagos.sum(:monto_pagado)
    @logias = logias_tesoreria

    respond_to do |format|
      format.html { @pagos = @pagos.recientes.page(params[:page]) }
      format.xlsx { render xlsx: "recaudacion", filename: "recaudacion_#{@fecha_desde}_#{@fecha_hasta}.xlsx" }
    end
  end

  def morosos
    @cobros = cobros_scope.vencido.includes(:periodo_cobro, miembro: [:user, :logia])
    @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    @total = @cobros.sum(:monto)
    @logias = logias_tesoreria

    respond_to do |format|
      format.html { @cobros = @cobros.page(params[:page]) }
      format.xlsx { render xlsx: "morosos", filename: "morosos_#{Date.current}.xlsx" }
    end
  end

  def recibo
    @pago = Pago.where(cobro_id: cobros_scope.select(:id)).find(params[:pago_id])
  end

  private

  def authorize_reportes
    authorize :reporte, "#{action_name}?"
  end

  def cobros_scope
    ids = logia_ids_tesoreria
    ids.nil? ? Cobro.all : Cobro.por_logia(ids)
  end

  # Una fecha mal escrita en la URL vale como vacía, en vez de dar un 500.
  def fecha_param(clave)
    Date.iso8601(params[clave].to_s) if params[clave].present?
  rescue Date::Error
    nil
  end
end
