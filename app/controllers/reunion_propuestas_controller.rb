# Puntos para el orden del día: los convocados los proponen antes de la reunión y quien la gestiona los incluye o
# los descarta. El alcance es el de la reunión (AlcanceReuniones).
class ReunionPropuestasController < ApplicationController
  before_action -> { requiere_modulo!(:reuniones) }
  before_action :set_reunion
  before_action :exigir_gestion, only: [:incluir, :descartar]
  before_action :set_propuesta, only: [:incluir, :descartar]

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    ficha = @reunion.convocados.find_by(id: current_miembro&.id)
    return volver(alert: "Solo proponen puntos los convocados.") unless ficha
    return volver(alert: "Ya no se reciben puntos: la convocatoria ya empezó o se canceló.") unless @reunion.admite_propuestas?

    propuesta = @reunion.reunion_propuestas.new(texto: params.require(:reunion_propuesta).permit(:texto)[:texto], miembro: ficha)
    if propuesta.save
      avisar(@reunion.user, "reunion_propuesta", "Punto propuesto para #{@reunion.titulo}", propuesta.texto) unless @reunion.user_id == current_user.id
      volver(notice: "Punto enviado. Si se incluye, entra en el orden del día con tu nombre.")
    else
      volver(alert: propuesta.errors.full_messages.to_sentence)
    end
  end

  def incluir
    return volver(alert: "Ese punto ya tiene respuesta.") unless @propuesta.pendiente? && !@reunion.cancelada?

    @propuesta.incluir!
    autor = @propuesta.miembro.user
    avisar(autor, "reunion_propuesta_incluida", "Tu punto entró en el orden del día", @reunion.titulo) unless autor == current_user
    volver(notice: "Incluido en el orden del día.")
  rescue ActiveRecord::RecordInvalid
    volver(alert: "No cabe: el orden del día ya es demasiado largo. Edítalo antes de incluir más puntos.")
  end

  def descartar
    @propuesta.descartada! if @propuesta.pendiente?
    volver(notice: "Punto descartado.")
  end

  private

  def set_reunion
    @reunion = Reunion.where(logia_id: logia_ids_de_reuniones).find(params[:reunion_id])
  end

  def set_propuesta
    @propuesta = @reunion.reunion_propuestas.find(params[:id])
  end

  def exigir_gestion
    redirect_to reunion_path(@reunion), alert: "No gestionas esta convocatoria." unless gestiona_reunion?(@reunion)
  end

  def volver(**flash) = redirect_to(reunion_path(@reunion, anchor: "propuestas"), **flash)

  def avisar(user, tipo, titulo, cuerpo)
    NotificacionService.crear!(user: user, tipo: tipo, titulo: titulo.truncate(120), cuerpo: cuerpo.truncate(200),
                               url: "/reuniones/#{@reunion.id}#propuestas", logia: @reunion.logia)
  end
end
