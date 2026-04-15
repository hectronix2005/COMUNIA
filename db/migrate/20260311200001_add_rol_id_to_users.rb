class AddRolIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :rol_ref, foreign_key: { to_table: :roles }, null: true
  end
end
