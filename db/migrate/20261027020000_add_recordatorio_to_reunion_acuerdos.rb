class AddRecordatorioToReunionAcuerdos < ActiveRecord::Migration[8.1]
  def change
    add_column :reunion_acuerdos, :recordatorio_enviado_at, :datetime
  end
end
