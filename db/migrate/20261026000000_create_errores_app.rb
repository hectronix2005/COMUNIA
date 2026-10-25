# Errores no controlados de la app, agrupados por huella (ver ErrorApp).
class CreateErroresApp < ActiveRecord::Migration[8.1]
  def change
    create_table :errores_app do |t|
      t.string   :huella, null: false
      t.string   :clase, null: false
      t.text     :mensaje
      t.string   :ubicacion
      t.string   :origen
      t.text     :traza
      t.integer  :veces, null: false, default: 1
      t.datetime :primera_vez, null: false
      t.datetime :ultima_vez, null: false
      t.datetime :resuelto_at
      t.timestamps
    end
    add_index :errores_app, :huella, unique: true
    add_index :errores_app, :ultima_vez
  end
end
