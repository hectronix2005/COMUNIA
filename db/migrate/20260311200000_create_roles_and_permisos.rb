class CreateRolesAndPermisos < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.string :nombre, null: false
      t.string :codigo, null: false
      t.string :descripcion
      t.boolean :es_sistema, default: false, null: false
      t.datetime :created_at, null: false
    end

    add_index :roles, :nombre, unique: true
    add_index :roles, :codigo, unique: true

    create_table :permisos do |t|
      t.string :recurso, null: false
      t.string :accion, null: false
      t.string :descripcion
      t.datetime :created_at, null: false
    end

    add_index :permisos, [:recurso, :accion], unique: true

    create_table :rol_permisos do |t|
      t.bigint :rol_id, null: false
      t.bigint :permiso_id, null: false
    end

    add_index :rol_permisos, [:rol_id, :permiso_id], unique: true
    add_foreign_key :rol_permisos, :roles, column: :rol_id
    add_foreign_key :rol_permisos, :permisos, column: :permiso_id
  end
end
