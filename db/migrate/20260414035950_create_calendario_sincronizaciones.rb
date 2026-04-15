class CreateCalendarioSincronizaciones < ActiveRecord::Migration[8.0]
  def change
    create_table :calendario_sincronizaciones do |t|
      t.references :logia_solicitante, null: false, foreign_key: { to_table: :logias }
      t.references :logia_destino,     null: false, foreign_key: { to_table: :logias }
      t.references :solicitado_por,    null: false, foreign_key: { to_table: :users }
      t.string     :estado,            null: false, default: "pendiente"
      t.text       :mensaje

      t.timestamps
    end

    add_index :calendario_sincronizaciones, [:logia_solicitante_id, :logia_destino_id], unique: true,
              name: "idx_cal_sync_unique_pair"
    add_index :calendario_sincronizaciones, :estado
  end
end
