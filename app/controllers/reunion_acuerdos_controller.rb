# Acuerdos de la reunión: quien la gestiona los apunta (qué, quién se encarga y para cuándo) y los borra; los da por
# cumplidos quien se encarga o quien gestiona. El alcance es el de la reunión (AlcanceReuniones).
class ReunionAcuerdosController < ApplicationController
  before_action -> { requiere_modulo!(:reuniones) }
  before_action :set_reunion
  before_action :exigir_gestion, only: [:create, :destroy]
  before_action :set_acuerdo, only: [:cumplir, :destroy]

  def create
    return volver(alert: "Los acuerdos se apuntan desde que empieza la convocatoria.") unless @reunion.admite_acuerdos?

    acuerdo = @reunion.reunion_acuerdos.new(params.require(:reunion_acuerdo).permit(:texto, :responsable_id, :vence_el))
    if acuerdo.save
      avisar(acuerdo) if acuerdo.responsable && acuerdo.responsable.user_id != current_user.id
      volver(notice: acuerdo.responsable ? "Acuerdo apuntado: se avisó a #{acuerdo.responsable.user.nombre_corto}." : "Acuerdo apuntado.")
    else
      volver(alert: acuerdo.errors.full_messages.to_sentence)
    end
  end

  def cumplir
    return volver(alert: "Solo lo da por cumplido quien se encarga o quien gestiona.") unless puede_cumplir?

    @acuerdo.update!(cumplido_at: Time.current) unless @acuerdo.cumplido?
    params[:desde] == "panel" ? redirect_to(dashboard_path, notice: "Acuerdo cumplido.") : volver(notice: "Acuerdo cumplido.")
  end

  def destroy
    @acuerdo.destroy!
    volver(notice: "Acuerdo borrado.")
  end

  private

  def set_reunion
    @reunion = Reunion.where(logia_id: logia_ids_de_reuniones).find(params[:reunion_id])
  end

  # Desde la reunión se cumplen también los que quedaron pendientes en reuniones anteriores del mismo grupo.
  def set_acuerdo
    @acuerdo = ReunionAcuerdo.joins(:reunion).where(reuniones: { logia_id: @reunion.logia_id }).find(params[:id])
  end

  def exigir_gestion
    redirect_to reunion_path(@reunion), alert: "No gestionas esta convocatoria." unless gestiona_reunion?(@reunion)
  end

  def puede_cumplir? = gestiona_reunion?(@reunion) || (current_miembro && @acuerdo.responsable_id == current_miembro.id)

  def volver(**flash) = redirect_to(reunion_path(@reunion, anchor: "acuerdos"), **flash)

  def avisar(acuerdo)
    plazo = " (para el #{I18n.l(acuerdo.vence_el, format: '%-d de %B')})" if acuerdo.vence_el
    NotificacionService.crear!(user: acuerdo.responsable.user, tipo: "reunion_acuerdo", titulo: "Te encargas de un acuerdo#{plazo}",
                               cuerpo: acuerdo.texto.truncate(200), url: "/reuniones/#{@reunion.id}#acuerdos", logia: @reunion.logia)
  end
end
