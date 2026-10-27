class AddActaAprobadaToReuniones < ActiveRecord::Migration[8.1]
  def change
    add_column :reuniones, :acta_aprobada_at, :datetime
    add_reference :reuniones, :acta_aprobada_en, foreign_key: { to_table: :reuniones, on_delete: :nullify }
  end
end
