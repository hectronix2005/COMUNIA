class AddCalendarioSemillaToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :calendario_semilla, :string
    add_index :users, :calendario_semilla, unique: true
  end
end
