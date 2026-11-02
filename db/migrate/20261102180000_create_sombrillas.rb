# Comunidades sombrilla: barrio → localidad → ciudad, sin admin. Se pertenece por estar en una comunidad de
# categoría Barrio anclada a un barrio (logias.sombrilla_id). Solo muro, eventos y noticias; nada del edificio sube.
class CreateSombrillas < ActiveRecord::Migration[8.1]
  LOCALIDADES_BOGOTA = [
    "Usaquén", "Chapinero", "Santa Fe", "San Cristóbal", "Usme", "Tunjuelito", "Bosa", "Kennedy", "Fontibón",
    "Engativá", "Suba", "Barrios Unidos", "Teusaquillo", "Los Mártires", "Antonio Nariño", "Puente Aranda",
    "La Candelaria", "Rafael Uribe Uribe", "Ciudad Bolívar", "Sumapaz"
  ].freeze

  class SombrillaMigracion < ActiveRecord::Base
    self.table_name = "sombrillas"
  end

  def up
    create_table :sombrillas do |t|
      t.string :nombre, null: false
      t.string :nivel, null: false
      t.references :padre, foreign_key: { to_table: :sombrillas }
      t.string :slug, null: false
      t.string :noticias_busquedas, array: true, default: [], null: false
      t.timestamps
    end
    add_index :sombrillas, :slug, unique: true
    add_check_constraint :sombrillas, "nivel IN ('barrio', 'localidad', 'ciudad')", name: "sombrillas_nivel"

    add_reference :logias, :sombrilla, foreign_key: true
    add_column :users, :visibilidad_sombrilla, :string

    create_table :sombrilla_publicaciones do |t|
      t.references :sombrilla, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :comunidad, null: false, foreign_key: { to_table: :logias }
      t.text :contenido, null: false
      t.boolean :oculta, default: false, null: false
      t.timestamps
    end
    add_index :sombrilla_publicaciones, [:sombrilla_id, :created_at]

    create_table :sombrilla_comentarios do |t|
      t.references :publicacion, null: false, foreign_key: { to_table: :sombrilla_publicaciones }
      t.references :user, null: false, foreign_key: true
      t.references :comunidad, null: false, foreign_key: { to_table: :logias }
      t.text :contenido, null: false
      t.boolean :oculta, default: false, null: false
      t.timestamps
    end

    create_table :sombrilla_eventos do |t|
      t.references :sombrilla, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :comunidad, null: false, foreign_key: { to_table: :logias }
      t.string :titulo, null: false
      t.text :descripcion
      t.string :lugar
      t.datetime :inicio, null: false
      t.boolean :oculta, default: false, null: false
      t.timestamps
    end
    add_index :sombrilla_eventos, [:sombrilla_id, :inicio]

    create_table :sombrilla_reportes do |t|
      t.references :reportable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.references :comunidad, null: false, foreign_key: { to_table: :logias }
      t.timestamps
    end
    add_index :sombrilla_reportes, [:reportable_type, :reportable_id, :user_id], unique: true, name: "index_sombrilla_reportes_unicos"

    change_column_null :noticias, :logia_id, true
    add_reference :noticias, :sombrilla, foreign_key: true
    add_index :noticias, [:sombrilla_id, :url], unique: true
    add_index :noticias, [:sombrilla_id, :publicada_en]
    add_check_constraint :noticias, "num_nonnulls(logia_id, sombrilla_id) = 1", name: "noticias_de_una_sola"

    sembrar_bogota
  end

  def down
    remove_check_constraint :noticias, name: "noticias_de_una_sola"
    execute "DELETE FROM noticias WHERE sombrilla_id IS NOT NULL"
    remove_reference :noticias, :sombrilla, foreign_key: true, index: false
    change_column_null :noticias, :logia_id, false
    drop_table :sombrilla_reportes
    drop_table :sombrilla_eventos
    drop_table :sombrilla_comentarios
    drop_table :sombrilla_publicaciones
    remove_column :users, :visibilidad_sombrilla
    remove_reference :logias, :sombrilla, foreign_key: true
    drop_table :sombrillas
  end

  private

  # Bogotá con sus 20 localidades y el primer barrio, Cedritos (Usaquén). Los demás barrios los crea el superadmin.
  def sembrar_bogota
    SombrillaMigracion.reset_column_information
    bogota = SombrillaMigracion.create!(nombre: "Bogotá", nivel: "ciudad", slug: "bogota", noticias_busquedas: ["Bogotá"])
    localidades = LOCALIDADES_BOGOTA.to_h do |nombre|
      [nombre, SombrillaMigracion.create!(nombre: nombre, nivel: "localidad", padre_id: bogota.id, slug: nombre.parameterize,
                                          noticias_busquedas: ["localidad de #{nombre}"])]
    end
    SombrillaMigracion.create!(nombre: "Cedritos", nivel: "barrio", padre_id: localidades["Usaquén"].id, slug: "cedritos",
                               noticias_busquedas: ["Cedritos Bogotá"])
  end
end
