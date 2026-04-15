class AddLogiaIdToRoles < ActiveRecord::Migration[8.0]
  def change
    add_reference :roles, :logia, null: true, foreign_key: true
  end
end
