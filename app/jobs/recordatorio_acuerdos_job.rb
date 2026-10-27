# Cada mañana: a quien se encarga de un acuerdo sin cumplir que vence hoy o mañana se le recuerda (una sola vez por
# acuerdo). No a quien ya no es miembro activo, ni de una reunión cancelada o de un grupo sin el módulo.
class RecordatorioAcuerdosJob < ApplicationJob
  queue_as :default

  def perform
    ReunionAcuerdo.pendientes.where(recordatorio_enviado_at: nil, vence_el: Date.current..Date.tomorrow)
                  .joins(:responsable).merge(Miembro.activos)
                  .includes(reunion: :logia, responsable: :user).find_each do |acuerdo|
      reunion = acuerdo.reunion
      next if reunion.cancelada? || !reunion.logia.modulo?(:reuniones)

      acuerdo.update_column(:recordatorio_enviado_at, Time.current)
      cuando = acuerdo.vence_el == Date.current ? "hoy" : "mañana"
      NotificacionService.crear!(user: acuerdo.responsable.user, tipo: "reunion_acuerdo", titulo: "Vence #{cuando}: #{acuerdo.texto.truncate(80)}",
                                 cuerpo: "Acuerdo de «#{reunion.titulo}». Cuando esté, márcalo como hecho.",
                                 url: "/reuniones/#{reunion.id}#acuerdos", logia: reunion.logia)
    end
  end
end
