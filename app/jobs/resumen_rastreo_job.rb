# A las 9 p. m. (config/recurring.yml) manda a los superadmins el resumen del día del rastreo de pruebas
# (ResumenRastreo), como aviso de COMUNIA con push. Si nadie entró, no avisa.
class ResumenRastreoJob < ApplicationJob
  queue_as :default

  def perform(fecha = Time.zone.today.iso8601)
    resumen = ResumenRastreo.new(Date.iso8601(fecha))
    return if resumen.vacio?

    User.joins(:rol_ref).where(roles: { codigo: "super_admin" }).find_each do |user|
      NotificacionService.crear!(user:, tipo: "rastreo", titulo: resumen.titulo, cuerpo: resumen.cuerpo, url: "/rastreo")
    end
  end
end
