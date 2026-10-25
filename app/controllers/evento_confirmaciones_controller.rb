class EventoConfirmacionesController < ApplicationController
  def create
    # La ruta anidada manda :calendario_id; leer :calendario_evento_id daba siempre 404.
    evento = CalendarioEvento.de_logias(logia_ids_de_la_organizacion).find(params[:calendario_id])
    return head(:unprocessable_entity) unless params[:estado].in?(EventoConfirmacion.estados.keys)

    conf = evento.evento_confirmaciones.find_or_initialize_by(user: current_user)
    conf.estado = params[:estado]
    conf.nota = params[:nota]
    conf.save!
    redirect_back fallback_location: calendario_path(evento), notice: "Asistencia registrada."
  end
end
