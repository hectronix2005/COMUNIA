class CumpleanosNotificacionJob < ApplicationJob
  queue_as :default

  def perform
    hoy = Date.current

    Logia.tenants_raiz.find_each do |tenant|
      logia_ids = [tenant.id] + tenant.logias.pluck(:id)
      miembros = Miembro.where(logia_id: logia_ids).activos.includes(:user, :familiares)

      # Familiares con cumpleaños hoy
      cumpleaneros = []
      miembros.each do |m|
        m.familiares.con_cumpleanos.each do |f|
          next unless f.fecha_nacimiento.month == hoy.month && f.fecha_nacimiento.day == hoy.day
          cumpleaneros << { familiar: f, miembro: m }
        end
      end

      next if cumpleaneros.empty?

      # Notificar a todos los miembros del tenant
      users = User.joins(:miembro).where(miembros: { logia_id: logia_ids })

      cumpleaneros.each do |c|
        nombre = c[:familiar].nombre_completo
        parentesco = c[:familiar].parentesco
        miembro_nombre = c[:miembro].user.nombre_completo

        users.find_each do |user|
          NotificacionService.crear!(
            user:     user,
            tipo:     "cumpleanos",
            titulo:   "Cumpleaños: #{nombre}",
            cuerpo:   "#{parentesco} de #{miembro_nombre}",
            url:      "/hospitalia/cumpleanos",
            logia:    tenant
          )
        end
      end
    end
  end
end
