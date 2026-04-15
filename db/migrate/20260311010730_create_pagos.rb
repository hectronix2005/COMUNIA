class CreatePagos < ActiveRecord::Migration[8.0]
  def change
    create_table :pagos do |t|
      t.references :cobro, null: false, foreign_key: true
      t.string :numero_rc
      t.decimal :monto_pagado, precision: 10, scale: 2, null: false
      t.date :fecha_pago, null: false
      t.string :metodo_pago, null: false, default: "transferencia"
      t.text :observaciones
      t.references :validado_por, foreign_key: { to_table: :users }
      t.datetime :validado_at

      t.timestamps
    end

    add_index :pagos, :numero_rc, unique: true
  end
end
