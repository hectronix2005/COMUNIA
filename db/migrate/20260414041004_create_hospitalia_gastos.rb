class CreateHospitaliaGastos < ActiveRecord::Migration[8.0]
  def change
    create_table :hospitalia_gastos do |t|
      t.string  :concepto,       null: false
      t.decimal :monto,          null: false, precision: 12, scale: 2
      t.date    :fecha,          null: false
      t.text    :descripcion
      t.bigint  :logia_id,       null: false
      t.bigint  :user_id,        null: false
      t.bigint  :beneficiario_id

      t.timestamps
    end

    add_index :hospitalia_gastos, :logia_id
    add_index :hospitalia_gastos, :fecha
  end
end
