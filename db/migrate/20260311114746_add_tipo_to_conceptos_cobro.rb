class AddTipoToConceptosCobro < ActiveRecord::Migration[8.0]
  def change
    add_column :conceptos_cobros, :tipo, :integer, null: false, default: 0
  end
end
