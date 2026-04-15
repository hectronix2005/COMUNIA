class FixLogiasCodigoUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :logias, :codigo, name: "index_logias_on_codigo"
    add_index :logias, %i[tenant_id codigo], unique: true, name: "index_logias_on_tenant_id_and_codigo"
  end
end
