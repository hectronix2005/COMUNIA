class CreateCobros < ActiveRecord::Migration[8.0]
  def change
    create_table :cobros do |t|
      t.references :periodo_cobro, null: false, foreign_key: true
      t.references :miembro, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.integer :estado, null: false, default: 0

      t.timestamps
    end

    add_index :cobros, [:periodo_cobro_id, :miembro_id], unique: true
    add_index :cobros, :estado
  end
end
