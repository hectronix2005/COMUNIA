class CreateNegocioFavoritos < ActiveRecord::Migration[8.0]
  def change
    create_table :negocio_favoritos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :negocio_anuncio, null: false, foreign_key: true

      t.timestamps
    end
    add_index :negocio_favoritos, [:user_id, :negocio_anuncio_id], unique: true, name: "idx_neg_fav_user_anuncio"
  end
end
