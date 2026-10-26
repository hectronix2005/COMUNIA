# Votaciones de una reunión: una pregunta de sí / no / abstención que votan los convocados, un voto por
# persona. Secreta por defecto: solo se ven los totales.
class CreateReunionVotaciones < ActiveRecord::Migration[8.1]
  def change
    create_table :reunion_votaciones do |t|
      t.references :reunion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :pregunta, null: false
      t.boolean :secreta, null: false, default: true
      t.integer :estado, null: false, default: 0
      t.datetime :cerrada_at
      t.timestamps
    end

    create_table :reunion_votos do |t|
      t.references :reunion_votacion, null: false, foreign_key: true
      t.references :miembro, null: false, foreign_key: true
      t.integer :opcion, null: false
      t.timestamps
    end
    add_index :reunion_votos, [:reunion_votacion_id, :miembro_id], unique: true
  end
end
