class CreateHospitaliaRecaudos < ActiveRecord::Migration[8.0]
  def change
    create_table :hospitalia_recaudos do |t|
      t.string  :concepto,    null: false
      t.decimal :monto,       null: false, precision: 12, scale: 2
      t.date    :fecha,       null: false
      t.text    :descripcion
      t.bigint  :logia_id,    null: false
      t.bigint  :user_id,     null: false
      t.bigint  :miembro_id

      t.timestamps
    end

    add_index :hospitalia_recaudos, :logia_id
    add_index :hospitalia_recaudos, :fecha
  end
end
