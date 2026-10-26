class AddSerieToReuniones < ActiveRecord::Migration[8.1]
  def change
    add_column :reuniones, :serie, :string
    add_index :reuniones, [:serie, :inicio]
  end
end
