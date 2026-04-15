class CreateBibliotecaCalificaciones < ActiveRecord::Migration[8.0]
  def change
    create_table :biblioteca_calificaciones do |t|
      t.bigint  :libro_id,    null: false
      t.bigint  :user_id,     null: false
      t.integer :puntuacion,  null: false
      t.text    :comentario

      t.timestamps
    end

    add_index :biblioteca_calificaciones, :libro_id
    add_index :biblioteca_calificaciones, [:libro_id, :user_id], unique: true
  end
end
