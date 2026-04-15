class CreateCargos < ActiveRecord::Migration[8.0]
  def change
    create_table :cargos do |t|
      t.string  :nombre,   null: false
      t.integer :logia_id, null: false
      t.boolean :activo,   null: false, default: true
      t.timestamps
    end
    add_index :cargos, :logia_id
    add_index :cargos, [ :logia_id, :nombre ], unique: true
    add_foreign_key :cargos, :logias
  end
end
