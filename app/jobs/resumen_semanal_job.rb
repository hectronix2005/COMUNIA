# Cada lunes, a cada miembro activo de cada comunidad, lo de su semana (ResumenSemanal) como aviso: a la campana
# y, si lo tiene activado, al teléfono. Sin que nadie lo pida, porque lo que llega solo es lo que más trae de
# vuelta. A quien no le toca nada esa semana no se le escribe. Sustituye al aviso semanal de cumpleaños.
class ResumenSemanalJob < ApplicationJob
  queue_as :default

  def perform
    # La comunidad de demostración (Demo) es de cuentas ficticias: a nadie le sirve su resumen.
    Logia.tenants_raiz.where.not(slug: Demo::SLUG).find_each do |comunidad|
      ids = [comunidad.id, *comunidad.logias.ids]
      User.where(id: Miembro.where(logia_id: ids).activos.select(:user_id)).find_each do |user|
        resumen = ResumenSemanal.new(comunidad, user:)
        next if resumen.vacio?

        NotificacionService.crear!(user:, tipo: "resumen_semanal", titulo: resumen.titulo, cuerpo: resumen.cuerpo.truncate(240),
                                   url: "/semana", logia: comunidad)
      end
    end
  end
end
