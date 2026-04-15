class CreateMiembros < ActiveRecord::Migration[8.0]
  def change
    create_table :miembros do |t|
      t.references :user, null: false, foreign_key: true
      t.references :logia, null: false, foreign_key: true
      t.string :numero_miembro, null: false
      t.string :cedula, null: false
      t.string :grado
      t.integer :estado, null: false, default: 0

      t.timestamps
    end

    add_index :miembros, :numero_miembro, unique: true
    add_index :miembros, :cedula, unique: true
    add_index :miembros, :estado
  end
end
