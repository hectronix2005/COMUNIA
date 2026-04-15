class AddTenantIdToLogias < ActiveRecord::Migration[8.0]
  def change
    add_reference :logias, :tenant, null: true, foreign_key: { to_table: :logias }
  end
end
