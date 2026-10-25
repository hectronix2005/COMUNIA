# Errores no controlados (peticiones y trabajos), agrupados por huella: la clase y la primera línea de la
# traza que es del proyecto, sin el número de línea para que un despliegue no la cambie. El superadmin los
# ve en /errores; la primera vez de cada huella, o si vuelve después de darla por resuelta, le llega una
# notificación. Se guardan el mensaje y la traza, nunca los parámetros ni la ruta de la petición.
class ErrorApp < ApplicationRecord
  self.table_name = "errores_app"

  # DENUNCIAPP promete anonimato: de sus errores se guardan la clase y la traza (solo líneas de código),
  # nunca el mensaje, que puede llevar datos de la denuncia.
  SIN_MENSAJE = %w[Denuncias:: PasesController].freeze

  scope :abiertos,  -> { where(resuelto_at: nil) }
  scope :resueltos, -> { where.not(resuelto_at: nil) }

  def self.registrar!(error, origen: nil)
    traza = Rails.backtrace_cleaner.clean(error.backtrace || [])
    ubicacion = traza.first.to_s
    huella = Digest::SHA256.hexdigest("#{error.class.name}|#{ubicacion.sub(/:\d+/, '')}")[0, 32]
    ahora = Time.current
    mensaje = error.message.to_s.truncate(1000) unless origen.to_s.start_with?(*SIN_MENSAJE)
    datos = { mensaje: mensaje, ubicacion: ubicacion.truncate(255),
              origen: origen&.truncate(255), traza: traza.first(30).join("\n"), ultima_vez: ahora }

    registro = find_by(huella: huella)
    if registro.nil?
      registro = create!(datos.merge(huella: huella, clase: error.class.name.truncate(255), primera_vez: ahora))
      avisar(registro)
    elsif registro.resuelto_at
      registro.update!(datos.merge(resuelto_at: nil, veces: registro.veces + 1))
      avisar(registro)
    else
      where(id: registro.id).update_all([ "veces = veces + 1, ultima_vez = ?", ahora ])
    end
    registro
  rescue ActiveRecord::RecordNotUnique
    # Dos peticiones con el mismo error a la vez: la otra ya lo creó y avisó.
    where(huella: huella).update_all([ "veces = veces + 1, ultima_vez = ?", ahora ])
  end

  def self.avisar(registro)
    User.joins(:rol_ref).where(roles: { codigo: "super_admin" }).find_each do |user|
      NotificacionService.crear!(user: user, tipo: "error_app", titulo: "Error en COMUNIA: #{registro.clase}",
                                 cuerpo: registro.ubicacion.presence || registro.origen, url: "/errores/#{registro.id}")
    end
  end
end
