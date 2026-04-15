class CreateBibliotecaLibros < ActiveRecord::Migration[8.0]
  def change
    create_table :biblioteca_libros do |t|
      t.string  :titulo,      null: false
      t.string  :autor
      t.text    :descripcion
      t.string  :categoria
      t.integer :anio
      t.string  :url_externa
      t.bigint  :logia_id,    null: false
      t.bigint  :user_id,     null: false
      t.boolean :activo,      null: false, default: true

      t.timestamps
    end

    add_index :biblioteca_libros, :logia_id
    add_index :biblioteca_libros, :user_id
    add_index :biblioteca_libros, :categoria
  end
end
