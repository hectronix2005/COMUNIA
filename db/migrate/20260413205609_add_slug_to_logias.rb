class AddSlugToLogias < ActiveRecord::Migration[8.0]
  def change
    add_column :logias, :slug, :string
    add_index  :logias, :slug, unique: true
  end
end
