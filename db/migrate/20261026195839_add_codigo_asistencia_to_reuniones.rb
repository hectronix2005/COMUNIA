class AddCodigoAsistenciaToReuniones < ActiveRecord::Migration[8.1]
  def change
    add_column :reuniones, :codigo_asistencia, :string
    add_index :reuniones, :codigo_asistencia, unique: true
  end
end
