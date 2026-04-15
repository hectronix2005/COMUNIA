class CreateTarifas < ActiveRecord::Migration[8.0]
  def change
    create_table :tarifas do |t|
      t.references :logia, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.date :vigente_desde, null: false
      t.date :vigente_hasta
      t.jsonb :desglose, default: []
      t.references :creado_por, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :tarifas, [:logia_id, :vigente_desde]
  end
end
