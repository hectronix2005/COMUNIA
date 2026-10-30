class AddRecorridoVistoAtToUsers < ActiveRecord::Migration[8.1]
  # Recorrido guiado (rediseño del 29-oct-2026): arranca solo la primera vez que alguien entra. Al terminarlo u
  # omitirlo se guarda la fecha y no vuelve a salir; desde la Guía se puede repetir.
  def change
    add_column :users, :recorrido_visto_at, :datetime
  end
end
