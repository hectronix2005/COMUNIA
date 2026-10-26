# La dirección a la que se suscribe el calendario del teléfono (webcal). Su app la pide sola cada pocas horas,
# sin sesión ni navegador moderno: por eso no hereda de ApplicationController (Devise, allow_browser, tenant).
# Lleva lo mismo que esa persona ve en el calendario de la app, desde un mes atrás hasta un año adelante.
class SuscripcionCalendarioController < ActionController::Base
  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  def show
    user = User.por_token_de_calendario(params[:token])
    return head(:not_found) unless user && vigente?(user)

    tenant = "/t/#{user.logia.slug}"
    eventos = CalendarioEvento.de_logias(CalendarioSincronizacion.logia_ids_visibles_para(user.logia_id))
                              .en_rango(1.month.ago, 1.year.from_now).includes(:reunion).ordenados.limit(500)
    datos = eventos.map do |e|
      url = e.reunion ? reunion_url(e.reunion, script_name: tenant) : calendario_url(e, script_name: tenant)
      e.datos_ics(url)
    end

    response.set_header("Cache-Control", "private, no-store")
    send_data Ics.calendario(datos, nombre: user.logia.nombre_display, refrescar: "PT4H"),
              type: :ics, disposition: "inline", filename: "comunia.ics"
  end

  private

  # Quien ya no puede entrar, o hoy no es miembro activo (retirado o en un periodo inactivo), deja de recibir el calendario.
  def vigente?(user)
    user.logia && user.active_for_authentication? && !user.solo_red? && (user.miembro.nil? || user.miembro.cobrable_en?(Date.current))
  end
end
