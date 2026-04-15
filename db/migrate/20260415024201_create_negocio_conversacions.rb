class CreateNegocioConversacions < ActiveRecord::Migration[8.0]
  def change
    create_table :negocio_conversacions do |t|
      t.references :negocio_anuncio, null: false, foreign_key: true
      t.integer :comprador_id
      t.integer :vendedor_id
      t.datetime :ultimo_mensaje_at

      t.timestamps
    end
    add_index :negocio_conversacions, [:negocio_anuncio_id, :comprador_id], unique: true, name: "idx_neg_conv_anuncio_comp"
    add_index :negocio_conversacions, :comprador_id
    add_index :negocio_conversacions, :vendedor_id
  end
end
