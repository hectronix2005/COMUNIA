class AddRecurrenciaToCalendarioEventos < ActiveRecord::Migration[8.0]
  def change
    add_column :calendario_eventos, :recurrencia_tipo,      :string
    add_column :calendario_eventos, :recurrencia_intervalo, :integer, default: 1
    add_column :calendario_eventos, :recurrencia_dias,      :string
    add_column :calendario_eventos, :recurrencia_fin,       :string,  default: "nunca"
    add_column :calendario_eventos, :recurrencia_hasta,     :date
    add_column :calendario_eventos, :recurrencia_count,     :integer, default: 10
    add_column :calendario_eventos, :serie_id,              :bigint

    add_index :calendario_eventos, :serie_id
  end
end
