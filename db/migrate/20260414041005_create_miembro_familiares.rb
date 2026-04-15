class CreateMiembroFamiliares < ActiveRecord::Migration[8.0]
  def change
    create_table :miembro_familiares do |t|
      t.bigint  :miembro_id,      null: false
      t.string  :nombre_completo, null: false
      t.string  :parentesco,      null: false
      t.date    :fecha_nacimiento

      t.timestamps
    end

    add_index :miembro_familiares, :miembro_id
  end
end
