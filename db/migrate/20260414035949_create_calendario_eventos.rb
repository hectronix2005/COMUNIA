class CreateCalendarioEventos < ActiveRecord::Migration[8.0]
  def change
    create_table :calendario_eventos do |t|
      t.string     :titulo,      null: false
      t.text       :descripcion
      t.datetime   :inicio,      null: false
      t.datetime   :fin,         null: false
      t.boolean    :todo_el_dia, null: false, default: false
      t.string     :color,       default: "#4285f4"
      t.string     :ubicacion
      t.references :logia,       null: false, foreign_key: true
      t.references :user,        null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendario_eventos, [:logia_id, :inicio]
    add_index :calendario_eventos, :inicio
  end
end
