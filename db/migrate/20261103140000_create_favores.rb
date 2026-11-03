# «Pido / ofrezco» entre vecinos (fase 2 del plan de engagement, 3-nov-2026): pedir o ofrecer una mano a los de la
# comunidad; quien puede ayudar responde por el chat privado. Y la pregunta de la semana en el muro. El módulo se
# enciende solo en la categoría Barrio.
class CreateFavores < ActiveRecord::Migration[8.1]
  def up
    create_table :favores do |t|
      t.references :logia, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :tipo, null: false
      t.string :titulo, null: false, limit: 120
      t.text :detalle
      t.string :estado, null: false, default: "abierto"
      t.datetime :resuelto_at
      t.references :ayudante, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :favores, %i[logia_id estado created_at]
    add_check_constraint :favores, "tipo IN ('pido', 'ofrezco')", name: "favores_tipo"
    add_check_constraint :favores, "estado IN ('abierto', 'resuelto', 'cerrado')", name: "favores_estado"

    create_table :favor_respuestas do |t|
      t.references :favor, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :favor_respuestas, %i[favor_id user_id], unique: true

    add_column :publicaciones, :pregunta, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE categorias SET modulos = array_append(modulos, 'pido_ofrezco')
      WHERE nombre = 'Barrio' AND NOT ('pido_ofrezco' = ANY(modulos))
    SQL
  end

  def down
    execute "UPDATE categorias SET modulos = array_remove(modulos, 'pido_ofrezco')"
    remove_column :publicaciones, :pregunta
    drop_table :favor_respuestas
    drop_table :favores
  end
end
