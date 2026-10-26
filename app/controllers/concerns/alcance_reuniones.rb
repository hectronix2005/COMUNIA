# Quién ve y quién convoca reuniones. Cada persona ve las de su grupo y las de la raíz de su comunidad (de ahí
# se convoca a toda la comunidad); quien gestiona un grupo (admin o cargo vigente), también las de ese grupo.
# Todo se recorta a la organización en la que se está: nada sale hacia otras comunidades.
module AlcanceReuniones
  extend ActiveSupport::Concern

  included do
    helper_method :gestiona_reunion?, :logias_convocables, :proxima_reunion
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
end
