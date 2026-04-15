class RemoveUniqueIndexFromPagosNumeroRc < ActiveRecord::Migration[8.0]
  def change
    remove_index :pagos, :numero_rc
    add_index :pagos, :numero_rc
  end
end
