# El recorrido guiado avisa aquí al terminarlo u omitirlo, para que no vuelva a arrancar solo. El invitado de la
# demostración comparte cuenta: a él se lo recuerda el navegador (sessionStorage), no la base de datos.
class RecorridoController < ApplicationController
  def update
    current_user.update_column(:recorrido_visto_at, Time.current) unless current_user.invitado? || current_user.recorrido_visto_at?
    head :no_content
  end
end
