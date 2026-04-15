class CreateNegocioAnuncios < ActiveRecord::Migration[8.0]
  def change
    create_table :negocio_anuncios do |t|
      t.string  :titulo,       null: false
      t.text    :descripcion
      t.string  :tipo,         null: false, default: "servicio"
      t.string  :categoria
      t.decimal :precio,       precision: 12, scale: 2
      t.string  :moneda,       default: "COP"
      t.string  :contacto
      t.string  :ubicacion
      t.boolean :activo,       null: false, default: true
      t.bigint  :logia_id,     null: false
      t.bigint  :user_id,      null: false

      t.timestamps
    end

    add_index :negocio_anuncios, :logia_id
    add_index :negocio_anuncios, :user_id
    add_index :negocio_anuncios, :tipo
    add_index :negocio_anuncios, [:logia_id, :activo]
  end
end
