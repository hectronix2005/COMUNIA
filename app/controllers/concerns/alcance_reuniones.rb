# Quién ve y quién convoca reuniones. Cada persona ve las de su grupo y las de la raíz de su comunidad (de ahí
# se convoca a toda la comunidad); quien gestiona un grupo (admin o cargo vigente), también las de ese grupo.
# Todo se recorta a la organización en la que se está: nada sale hacia otras comunidades.
module AlcanceReuniones
  extend ActiveSupport::Concern

  included do
    helper_method :gestiona_reunion?, :logias_convocables, :proxima_reunion, :proximos_eventos, :mis_acuerdos, :puede_llevar_a_reunion?
  end

  private

  def logias_convocables
    @logias_convocables ||= begin
      # logia_ids_gestionables da a cualquiera su propio grupo: aquí, como en modera?, cuenta el rol.
      admin = current_user.rol_ref&.es_super_admin? || current_user.rol_ref&.codigo == "admin_logia"
      ids = admin ? logia_ids_gestionables : []
      ids += [current_miembro.logia_id] if current_miembro&.miembro_cargos&.vigentes&.exists?
      Logia.where(id: ids & logia_ids_de_la_organizacion).order(:tenant_id, :nombre).to_a
    end
  end

  def gestiona_reunion?(reunion) = logias_convocables.any? { _1.id == reunion.logia_id }

  # Un evento lo gestiona quien lo creó o quien gestiona su grupo (lo mismo que para editarlo o borrarlo).
  def gestiona_evento?(evento) = evento.user_id == current_user.id || logia_ids_gestionables.include?(evento.logia_id)

  # Llevar un evento como reunión: en un grupo que se convoca y con el módulo de reuniones activo.
  def puede_llevar_a_reunion?(evento)
    evento.reunion.nil? && current_logia.modulo?(:reuniones) && logias_convocables.any? && gestiona_evento?(evento)
  end

  def logia_ids_de_reuniones
    @logia_ids_de_reuniones ||= begin
      propias = [current_miembro&.logia_id, current_user.logia_id, current_logia.organizacion.id].compact
      (propias + logias_convocables.map(&:id)).uniq & logia_ids_de_la_organizacion
    end
  end

  def proxima_reunion
    return @proxima_reunion if defined?(@proxima_reunion)
    @proxima_reunion = (Reunion.where(logia_id: logia_ids_de_reuniones).proximas.first if current_logia.modulo?(:reuniones))
  end

  # Los próximos eventos del calendario (no las reuniones, que tienen su tarjeta) en el mismo alcance: el grupo
  # de la persona, la raíz de su comunidad y los grupos que gestiona. Con la respuesta de cada quien.
  def proximos_eventos
    @proximos_eventos ||= begin
      eventos = CalendarioEvento.de_logias(logia_ids_de_reuniones).where.missing(:reunion)
                                .en_rango(Time.current, 30.days.from_now).includes(:logia).ordenados.limit(3).to_a
      respuestas = EventoConfirmacion.where(user: current_user, calendario_evento_id: eventos.map(&:id))
                                     .pluck(:calendario_evento_id, :estado).to_h
      eventos.map { [_1, respuestas[_1.id]] }
    end
  end

  # Los acuerdos sin cumplir de los que se encarga quien entra, en las reuniones que ve; los que vencen antes, primero.
  def mis_acuerdos
    return ReunionAcuerdo.none unless current_miembro && current_logia.modulo?(:reuniones)
    ReunionAcuerdo.pendientes.where(responsable: current_miembro).joins(:reunion)
                  .where(reuniones: { logia_id: logia_ids_de_reuniones }).includes(:reunion)
                  .order(Arel.sql("vence_el IS NULL"), :vence_el, :created_at).limit(5)
  end
end
