# Reuniones de un grupo o de toda la comunidad (tenida, encuentro, asamblea…): convocatoria con orden del día,
# confirmación (la del evento del calendario que se crea con ella), asistencia con quórum y acta.
class CreateReuniones < ActiveRecord::Migration[8.1]
  def up
    create_table :reuniones do |t|
      t.references :logia, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :calendario_evento, foreign_key: { on_delete: :nullify }
      t.string :titulo, null: false
      t.datetime :inicio, null: false
      t.datetime :fin, null: false
      t.string :lugar
      t.text :orden_del_dia
      t.integer :estado, null: false, default: 0
      t.text :acta
      t.datetime :acta_publicada_at
      t.datetime :recordatorio_enviado_at
      t.timestamps
    end
    add_index :reuniones, [:logia_id, :inicio]

    create_table :reunion_asistencias do |t|
      t.references :reunion, null: false, foreign_key: true
      t.references :miembro, null: false, foreign_key: true
      t.timestamps
    end
    add_index :reunion_asistencias, [:reunion_id, :miembro_id], unique: true

    # Todas las categorías que ya existen usan reuniones.
    execute "UPDATE categorias SET modulos = array_append(modulos, 'reuniones') WHERE NOT ('reuniones' = ANY(modulos))"
  end

  def down
    execute "UPDATE categorias SET modulos = array_remove(modulos, 'reuniones')"
    drop_table :reunion_asistencias
    drop_table :reuniones
  end
end
