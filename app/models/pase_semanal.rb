# Cuántos pases anónimos de DENUNCIAPP se le han firmado a un miembro en una
# semana ISO (lunes a domingo, hora de Bogotá). Es lo único que COMUNIA guarda
# de los pases: ni el mensaje cegado ni la firma.
class PaseSemanal < ApplicationRecord
  self.table_name = "pases_semanales"

  MAXIMO = 4

  belongs_to :miembro

  # Suma un pase a la semana del miembro si no ha llegado al máximo.
  # Atómico: dos peticiones simultáneas no pueden pasar ambas del límite.
  def self.reservar(miembro, ahora = Time.current)
    semana = ahora.to_date.beginning_of_week(:monday)
    insert_all([{ miembro_id: miembro.id, semana: semana }], unique_by: [:miembro_id, :semana])
    where(miembro_id: miembro.id, semana: semana)
      .where(cantidad: ...MAXIMO)
      .update_all("cantidad = cantidad + 1") == 1
  end
end
