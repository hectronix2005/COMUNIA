class CreateConceptosCobro < ActiveRecord::Migration[8.0]
  def change
    create_table :conceptos_cobros do |t|
      t.references :logia, null: false, foreign_key: true
      t.string :nombre, null: false
      t.decimal :monto, precision: 10, scale: 2, null: false, default: 0
      t.string :descripcion
      t.boolean :activo, null: false, default: true
      t.integer :orden, null: false, default: 0

      t.timestamps
    end

    add_index :conceptos_cobros, [:logia_id, :orden]
  end
end
