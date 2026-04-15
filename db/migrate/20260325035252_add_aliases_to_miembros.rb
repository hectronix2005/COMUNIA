class AddAliasesToMiembros < ActiveRecord::Migration[8.0]
  def change
    add_column :miembros, :aliases, :jsonb, default: [], null: false
  end
end
