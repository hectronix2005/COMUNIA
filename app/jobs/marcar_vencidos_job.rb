class MarcarVencidosJob < ApplicationJob
  queue_as :default

  def perform
    PeriodoCobro.activo.where("fecha_vencimiento < ?", Date.current).find_each do |periodo|
      periodo.cobros.pendiente.update_all(estado: Cobro.estados[:vencido])
    end
  end
end
