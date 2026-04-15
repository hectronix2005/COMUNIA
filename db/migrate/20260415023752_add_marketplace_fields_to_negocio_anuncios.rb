class AddMarketplaceFieldsToNegocioAnuncios < ActiveRecord::Migration[8.0]
  def change
    add_column :negocio_anuncios, :estado,       :string,  default: "disponible", null: false
    add_column :negocio_anuncios, :vistas_count, :integer, default: 0,            null: false
    add_index  :negocio_anuncios, :estado
  end
end
