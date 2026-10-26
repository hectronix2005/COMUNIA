class AddRecordatorioToCalendarioEventos < ActiveRecord::Migration[8.1]
  def change
    add_column :calendario_eventos, :recordatorio_enviado_at, :datetime
  end
end
