class CreateReunionAcuerdos < ActiveRecord::Migration[8.1]
  def change
    create_table :reunion_acuerdos do |t|
      t.references :reunion, null: false, foreign_key: { on_delete: :cascade }
      t.references :responsable, foreign_key: { to_table: :miembros, on_delete: :nullify }, index: false # índice: el de abajo
      t.string :texto, null: false
      t.date :vence_el
      t.datetime :cumplido_at
      t.timestamps
    end
    add_index :reunion_acuerdos, [:responsable_id, :cumplido_at]
  end
end
