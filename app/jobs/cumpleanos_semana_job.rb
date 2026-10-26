# Cada lunes, a cada miembro activo, los cumpleaños de familiares de su organización en los próximos 7 días:
# un motivo para entrar cada semana. El aviso del mismo día lo sigue dando CumpleanosNotificacionJob.
# Solo dentro de la organización, como la página de cumpleaños: nada sale hacia otras.
class CumpleanosSemanaJob < ApplicationJob
  queue_as :default

  def perform
    hoy = Date.current

    Logia.tenants_raiz.find_each do |tenant|
      logia_ids = [tenant.id] + tenant.logias.pluck(:id)
      miembros = Miembro.where(logia_id: logia_ids).activos

      cumpleanos = MiembroFamiliar.con_cumpleanos.where(miembro: miembros).includes(miembro: :user)
                                  .map { |f| [f, f.proximo_cumpleanos(hoy)] }
                                  .select { |_, fecha| fecha <= hoy + 6 }
                                  .sort_by { |f, fecha| [fecha, f.nombre_completo] }
      next if cumpleanos.empty?

      titulo = cumpleanos.one? ? "1 cumpleaños esta semana" : "#{cumpleanos.size} cumpleaños esta semana"
      cuerpo = cumpleanos.map { |f, fecha|
        "#{f.nombre_completo} (#{f.parentesco.downcase} de #{f.miembro.user.nombre_corto}), #{I18n.l(fecha, format: '%a %-d')}"
      }.join("; ").truncate(240)

      User.where(id: miembros.select(:user_id)).find_each do |user|
        NotificacionService.crear!(user: user, tipo: "cumpleanos_semana", titulo: titulo, cuerpo: cuerpo,
                                   url: "/hospitalia/cumpleanos?rango=7", logia: tenant)
      end
    end
  end
end
