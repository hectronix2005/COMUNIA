class CreateSolicitudesAcceso < ActiveRecord::Migration[8.1]
  def change
    add_column :logias, :codigo_acceso, :string
    add_index :logias, :codigo_acceso, unique: true
    add_column :users, :espera_aprobacion, :boolean, default: false, null: false

    create_table :solicitudes_acceso do |t|
      t.references :logia, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :nombre, null: false
      t.string :apellido, null: false
      t.string :email, null: false
      t.text :prueba, null: false
      t.string :estado, null: false, default: "pendiente"
      t.references :decidida_por, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :decidida_at
      t.string :motivo
      t.references :miembro, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :solicitudes_acceso, [:logia_id, :estado]
  end
end
