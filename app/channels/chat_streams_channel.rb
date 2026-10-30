# Los streams del chat (chat_tenant_<raíz>, chat_logia_<id>, chat_dm_<comunidad>_<a>_<b>). Además de la firma de Turbo, que
# no caduca, se comprueba al suscribirse que la persona sigue en esa comunidad: quien la deja y guardó el nombre
# firmado ya no recibe sus mensajes. En los privados, que los dos sigan en la comunidad del privado.
class ChatStreamsChannel < Turbo::StreamsChannel
  def subscribed
    stream_name = verified_stream_name_from_params
    if stream_name && permitido?(stream_name)
      stream_from stream_name
    else
      reject
    end
  end

  private

  def permitido?(stream_name)
    return true if current_user.rol_ref&.es_super_admin?

    case stream_name
    when /\Achat_(?:tenant|logia)_(\d+)\z/
      logia = Logia.find_by(id: $1)
      logia.present? && current_user.pertenece_a?(logia.organizacion)
    when /\Achat_dm_(\d+)_(\d+)_(\d+)\z/
      organizacion = Logia.find_by(id: $1)
      ids = [$2.to_i, $3.to_i]
      otro = User.find_by(id: (ids - [current_user.id]).first) if ids.include?(current_user.id)
      organizacion.present? && otro.present? &&
        current_user.pertenece_a?(organizacion) && otro.pertenece_a?(organizacion)
    else
      false
    end
  end
end
