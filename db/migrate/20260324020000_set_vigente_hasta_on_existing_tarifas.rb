class SetVigenteHastaOnExistingTarifas < ActiveRecord::Migration[8.0]
  def up
    # Tarifas sin vigente_hasta reciben fin de año actual como fecha final
    Tarifa.where(vigente_hasta: nil).find_each do |tarifa|
      tarifa.update_column(:vigente_hasta, Date.new(Date.current.year, 12, 31))
    end

    # Ahora hacer vigente_hasta NOT NULL
    change_column_null :tarifas, :vigente_hasta, false
  end

  def down
    change_column_null :tarifas, :vigente_hasta, true
  end
end
