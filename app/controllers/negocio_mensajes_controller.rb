class NegocioMensajesController < ApplicationController
  def create
    conv = NegocioConversacion.find(params[:negocio_conversacion_id])
    unless [conv.comprador_id, conv.vendedor_id].include?(current_user.id)
      redirect_to negocio_conversaciones_path, alert: "Sin permiso."
      return
    end

    msg = conv.mensajes.new(user: current_user, cuerpo: params.dig(:negocio_mensaje, :cuerpo))
    if msg.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("mensajes-list", partial: "negocio_mensajes/mensaje", locals: { mensaje: msg }),
            turbo_stream.replace("mensaje-form", partial: "negocio_mensajes/form", locals: { conversacion: conv, mensaje: NegocioMensaje.new })
          ]
        end
        format.html { redirect_to negocio_conversacion_path(conv) }
      end
    else
      redirect_to negocio_conversacion_path(conv), alert: msg.errors.full_messages.to_sentence
    end
  end
end
