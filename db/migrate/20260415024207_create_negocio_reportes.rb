class CreateNegocioReportes < ActiveRecord::Migration[8.0]
  def change
    create_table :negocio_reportes do |t|
      t.references :negocio_anuncio, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :motivo
      t.text :descripcion
      t.boolean :resuelto, default: false, null: false

      t.timestamps
    end
  end
end
