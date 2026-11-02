# Noticias de internet sobre cada comunidad (Google Noticias), que enciende su admin (Héctor, 2-nov-2026).
class CreateNoticias < ActiveRecord::Migration[8.1]
  def change
    add_column :logias, :noticias_activas, :boolean, default: false, null: false
    add_column :logias, :noticias_busquedas, :string, array: true, default: [], null: false

    create_table :noticias do |t|
      t.references :logia, null: false, foreign_key: true
      t.string :titulo, null: false
      t.string :medio
      t.string :url, null: false, limit: 2000
      t.string :busqueda
      t.datetime :publicada_en, null: false
      t.boolean :oculta, default: false, null: false
      t.timestamps
    end
    add_index :noticias, [:logia_id, :url], unique: true
    add_index :noticias, [:logia_id, :publicada_en]
  end
end
