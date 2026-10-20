# Conteo de pases anónimos (DENUNCIAPP) firmados a cada miembro por semana ISO.
# Solo el número: ni el mensaje cegado ni la firma se guardan en ningún sitio.
class CreatePasesSemanales < ActiveRecord::Migration[8.0]
  def change
    create_table :pases_semanales do |t|
      t.references :miembro, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date    :semana,   null: false
      t.integer :cantidad, null: false, default: 0
    end
    add_index :pases_semanales, [:miembro_id, :semana], unique: true
  end
end
