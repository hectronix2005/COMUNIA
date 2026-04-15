class AddBrandingToLogias < ActiveRecord::Migration[8.0]
  def change
    add_column :logias, :nombre_app, :string
    add_column :logias, :icono, :string
    add_column :logias, :lema, :string
    add_column :logias, :color_primario, :string
    add_column :logias, :termino_miembro, :string
    add_column :logias, :termino_logia, :string
    add_column :logias, :termino_cobro, :string
  end
end
