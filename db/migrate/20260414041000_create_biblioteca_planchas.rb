class CreateBibliotecaPlanchas < ActiveRecord::Migration[8.0]
  def change
    create_table :biblioteca_planchas do |t|
      t.string  :titulo,      null: false
      t.text    :descripcion
      t.string  :grado,       null: false, default: "Aprendiz"
      t.string  :autor
      t.integer :anio
      t.bigint  :logia_id,    null: false
      t.bigint  :user_id,     null: false
      t.boolean :activo,      null: false, default: true

      t.timestamps
    end

    add_index :biblioteca_planchas, :logia_id
    add_index :biblioteca_planchas, :user_id
    add_index :biblioteca_planchas, :grado
    add_index :biblioteca_planchas, [:logia_id, :grado]
  end
end
