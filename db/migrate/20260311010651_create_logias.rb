class CreateLogias < ActiveRecord::Migration[8.0]
  def change
    create_table :logias do |t|
      t.string :nombre, null: false
      t.string :codigo, null: false
      t.integer :rc_secuencia_actual, null: false, default: 0

      t.timestamps
    end
    add_index :logias, :codigo, unique: true
  end
end
