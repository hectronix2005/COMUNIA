class AddNombreVisibleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :nombre_visible, :string
  end
end
