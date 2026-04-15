class AddDescuentoToPagos < ActiveRecord::Migration[8.0]
  def change
    add_column :pagos, :descuento_porcentaje, :decimal, precision: 5, scale: 2, default: 0
    add_column :pagos, :descuento_monto, :decimal, precision: 10, scale: 2, default: 0
  end
end
