# Para el monitor externo (.github/workflows/disponibilidad.yml). /up solo dice que Rails arrancó; esto
# además pregunta a la base. La respuesta no dice qué falla: el detalle queda en el log.
class SaludController < ActionController::Base
  def show
    ActiveRecord::Base.with_connection { _1.select_value("SELECT 1") }
    render plain: "ok"
  rescue StandardError => e
    Rails.logger.error("salud: #{e.class}: #{e.message}")
    render plain: "error", status: :service_unavailable
  end
end
