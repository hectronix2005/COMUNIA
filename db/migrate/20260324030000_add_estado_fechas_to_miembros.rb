class AddEstadoFechasToMiembros < ActiveRecord::Migration[8.0]
  def change
    add_column :miembros, :estado_desde, :date
    add_column :miembros, :estado_hasta, :date
    add_column :miembros, :estado_motivo, :string
  end
end
