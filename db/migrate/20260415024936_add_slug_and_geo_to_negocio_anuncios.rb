class AddSlugAndGeoToNegocioAnuncios < ActiveRecord::Migration[8.0]
  def change
    add_column :negocio_anuncios, :slug,     :string
    add_index  :negocio_anuncios, :slug, unique: true
    add_column :negocio_anuncios, :latitud,  :decimal, precision: 10, scale: 6
    add_column :negocio_anuncios, :longitud, :decimal, precision: 10, scale: 6
  end
end
