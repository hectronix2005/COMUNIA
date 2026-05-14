class NotificacionService
  def self.crear!(user:, tipo:, titulo:, cuerpo: nil, url: nil, logia: nil, metadata: {})
    notificacion = Notificacion.create!(
      user: user, tipo: tipo, titulo: titulo,
      cuerpo: cuerpo, url: url, logia: logia, metadata: metadata
    )
    SendPushNotificationJob.perform_later(notificacion.id)
    broadcast_badge(user)
    notificacion
  end

  def self.broadcast_badge(user)
    count = user.notificaciones.no_leidas.count
    Turbo::StreamsChannel.broadcast_replace_to(
      "notificaciones_#{user.id}",
      target: "notification-badge",
      html: count > 0 ? "<span class='position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger' id='notification-badge' style='font-size:0.6rem;'>#{count > 99 ? '99+' : count}</span>".html_safe : "<span id='notification-badge'></span>".html_safe
    )
  end
end
