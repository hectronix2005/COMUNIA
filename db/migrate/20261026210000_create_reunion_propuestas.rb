class CreateReunionPropuestas < ActiveRecord::Migration[8.1]
  def change
    create_table :reunion_propuestas do |t|
      t.references :reunion, null: false, index: false, foreign_key: { on_delete: :cascade } # índice: el de abajo
      t.references :miembro, null: false, foreign_key: { on_delete: :cascade }
      t.string :texto, null: false
      t.integer :estado, null: false, default: 0
      t.timestamps
    end
    add_index :reunion_propuestas, [:reunion_id, :estado]
  end
end
