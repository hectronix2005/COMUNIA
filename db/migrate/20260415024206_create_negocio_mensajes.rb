class CreateNegocioMensajes < ActiveRecord::Migration[8.0]
  def change
    create_table :negocio_mensajes do |t|
      t.references :negocio_conversacion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :cuerpo
      t.boolean :leido, default: false, null: false

      t.timestamps
    end
  end
end
