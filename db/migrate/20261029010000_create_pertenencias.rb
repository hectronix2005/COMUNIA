class CreatePertenencias < ActiveRecord::Migration[8.1]
  # Una cuenta, varias comunidades (decisión de Héctor, 29-oct-2026): cada cuenta pertenece a una o más
  # organizaciones, con su logia y su rol en cada una. users.logia_id y users.rol_ref_id pasan a ser los de la
  # comunidad activa. Las fichas (miembros) son una por organización: cédula y número dejan de ser únicos en
  # todo COMUNIA y pasan a serlo por logia (el modelo lo comprueba por organización).
  def up
    create_table :pertenencias do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organizacion, null: false, foreign_key: { to_table: :logias }
      t.references :logia, null: false, foreign_key: true
      t.references :rol_ref, foreign_key: { to_table: :roles }
      t.timestamps
    end
    add_index :pertenencias, [:user_id, :organizacion_id], unique: true

    execute <<~SQL
      INSERT INTO pertenencias (user_id, organizacion_id, logia_id, rol_ref_id, created_at, updated_at)
      SELECT users.id, COALESCE(logias.tenant_id, logias.id), users.logia_id, users.rol_ref_id, NOW(), NOW()
      FROM users JOIN logias ON logias.id = users.logia_id
    SQL

    remove_index :miembros, :user_id, unique: true
    remove_index :miembros, :cedula, unique: true
    remove_index :miembros, :numero_miembro, unique: true
    add_index :miembros, :user_id
    add_index :miembros, [:user_id, :logia_id], unique: true
    add_index :miembros, [:logia_id, :cedula], unique: true
    add_index :miembros, [:logia_id, :numero_miembro], unique: true
    add_index :miembros, :cedula
  end

  def down
    remove_index :miembros, :cedula
    remove_index :miembros, [:logia_id, :numero_miembro]
    remove_index :miembros, [:logia_id, :cedula]
    remove_index :miembros, [:user_id, :logia_id]
    remove_index :miembros, :user_id
    add_index :miembros, :numero_miembro, unique: true
    add_index :miembros, :cedula, unique: true
    add_index :miembros, :user_id, unique: true
    drop_table :pertenencias
  end
end
