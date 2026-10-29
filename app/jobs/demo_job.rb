# Renueva cada noche la comunidad de demostración del modo invitado (Demo): fechas cercanas a hoy y nada de lo
# que se haya colado.
class DemoJob < ApplicationJob
  queue_as :default

  def perform
    Demo.preparar!
  end
end
