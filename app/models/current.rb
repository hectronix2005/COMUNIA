# Lo de la petición en curso. organizacion es la comunidad que se está mirando: User#miembro da la ficha de
# esa comunidad (ApplicationController la pone; fuera de una petición queda vacía).
class Current < ActiveSupport::CurrentAttributes
  attribute :organizacion
end
