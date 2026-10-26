# Votaciones dentro de una reunión: quien la gestiona abre una pregunta y la cierra; los convocados votan
# sí, no o abstención, una vez cada uno. El alcance es el de la reunión (AlcanceReuniones).
class ReunionVotacionesController < ApplicationController
  before_action -> { requiere_modulo!(:reuniones) }
  before_action :set_reunion
  before_action :exigir_gestion, only: [:create, :cerrar]
  before_action :set_votacion, only: [:votar, :cerrar]

  def create
    return redirect_to(reunion_path(@reunion), alert: "No se vota en una convocatoria cancelada.") if @reunion.cancelada?

    votacion = @reunion.reunion_votaciones.new(params.require(:reunion_votacion).permit(:pregunta, :secreta).merge(user: current_user))
    if votacion.save
      NotificarReunionJob.perform_later(@reunion.id, "votacion", votacion.pregunta)
      redirect_to reunion_path(@reunion, anchor: "votaciones"), notice: "Votación abierta: se avisó a los convocados."
    else
      redirect_to reunion_path(@reunion, anchor: "votaciones"), alert: votacion.errors.full_messages.to_sentence
    end
  end

  def votar
    ficha = @reunion.convocados.find_by(id: current_miembro&.id)
    return redirect_to(reunion_path(@reunion), alert: "Solo votan los convocados.") unless ficha
    return redirect_to(reunion_path(@reunion), alert: "La votación ya está cerrada.") if @votacion.cerrada?
    return head(:unprocessable_entity) unless params[:opcion].in?(ReunionVoto.opciones.keys)

    @votacion.reunion_votos.find_or_initialize_by(miembro: ficha).update!(opcion: params[:opcion])
    redirect_to reunion_path(@reunion, anchor: "votaciones"), notice: "Voto guardado."
  end

  def cerrar
    @votacion.update!(estado: :cerrada, cerrada_at: Time.current) if @votacion.abierta?
    redirect_to reunion_path(@reunion, anchor: "votaciones"), notice: "Votación cerrada."
  end

  private

  def set_reunion
    @reunion = Reunion.where(logia_id: logia_ids_de_reuniones).find(params[:reunion_id])
  end

  def set_votacion
    @votacion = @reunion.reunion_votaciones.find(params[:id])
  end

  def exigir_gestion
    redirect_to reunion_path(@reunion), alert: "No gestionas esta convocatoria." unless gestiona_reunion?(@reunion)
  end
end
