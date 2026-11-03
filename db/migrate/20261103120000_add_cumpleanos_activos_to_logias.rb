# En las comunidades de categoría Barrio, Cumpleaños está apagado hasta que lo encienda su admin (Héctor, 3-nov-2026).
class AddCumpleanosActivosToLogias < ActiveRecord::Migration[8.1]
  def change
    add_column :logias, :cumpleanos_activos, :boolean, null: false, default: false
  end
end
