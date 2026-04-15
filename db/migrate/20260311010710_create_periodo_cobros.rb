class CreatePeriodoCobros < ActiveRecord::Migration[8.0]
  def change
    create_table :periodo_cobros do |t|
      t.string :nombre, null: false
      t.integer :anio, null: false
      t.integer :mes, null: false
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.date :fecha_vencimiento, null: false
      t.integer :estado, null: false, default: 0
      t.references :creado_por, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :periodo_cobros, [:anio, :mes], unique: true
  end
end
