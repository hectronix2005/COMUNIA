class CreateMiembroCargos < ActiveRecord::Migration[8.0]
  def change
    create_table :miembro_cargos do |t|
      t.integer :miembro_id,      null: false
      t.integer :cargo_id,        null: false
      t.date    :desde,           null: false
      t.date    :hasta
      t.integer :asignado_por_id
      t.timestamps
    end
    add_index :miembro_cargos, :miembro_id
    add_index :miembro_cargos, :cargo_id
    add_foreign_key :miembro_cargos, :miembros
    add_foreign_key :miembro_cargos, :cargos
    add_foreign_key :miembro_cargos, :users, column: :asignado_por_id
  end
end
