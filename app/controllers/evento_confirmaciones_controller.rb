class EventoConfirmacionesController < ApplicationController
  def create
    evento = CalendarioEvento.find(params[:calendario_evento_id])
    conf = evento.evento_confirmaciones.find_or_initialize_by(user: current_user)
    conf.estado = params[:estado]
    conf.nota = params[:nota]
    conf.save!
    redirect_back fallback_location: calendario_path(evento), notice: "Asistencia registrada."
  end
end
