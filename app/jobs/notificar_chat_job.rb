class NotificarChatJob < ApplicationJob
  queue_as :default

  def perform(chat_mensaje_id)
    mensaje = ChatMensaje.find_by(id: chat_mensaje_id)
    return unless mensaje

    sender = mensaje.user
    sender_name = sender.nombre_chat

    if mensaje.dm?
      return unless mensaje.destinatario_id
      NotificacionService.crear!(
        user:     mensaje.destinatario,
        tipo:     "chat_dm",
        titulo:   "Mensaje de #{sender_name}",
        cuerpo:   mensaje.contenido.truncate(100),
        url:      "/chat?con=#{sender.id}",
        logia:    mensaje.logia,
        metadata: { sender_id: sender.id, chat_mensaje_id: mensaje.id }
      )
    else
      destinatarios = users_del_canal(mensaje).where.not(id: sender.id)
      destinatarios.find_each do |user|
        NotificacionService.crear!(
          user:     user,
          tipo:     "chat_canal",
          titulo:   "#{sender_name} en #{mensaje.canal == 'tenant' ? 'Canal General' : mensaje.logia.nombre}",
          cuerpo:   mensaje.contenido.truncate(100),
          url:      mensaje.canal == "logia" ? "/chat?canal=logia" : "/chat",
          logia:    mensaje.logia,
          metadata: { sender_id: sender.id, chat_mensaje_id: mensaje.id }
        )
      end
    end
  end

  private

  def users_del_canal(mensaje)
    if mensaje.canal == "logia"
      User.joins(:miembro).where(miembros: { logia_id: mensaje.logia_id })
    else
      # tenant canal — all members under the root tenant
      root_id = mensaje.logia.tenant_id || mensaje.logia_id
      logia_ids = [root_id] + Logia.where(tenant_id: root_id).pluck(:id)
      User.joins(:miembro).where(miembros: { logia_id: logia_ids })
    end
  end
end
