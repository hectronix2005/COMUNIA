class AddFechaIngresoToMiembros < ActiveRecord::Migration[8.0]
  def change
    add_column :miembros, :fecha_ingreso, :date
  end
end
