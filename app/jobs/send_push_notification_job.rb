class SendPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(notificacion_id)
    notificacion = Notificacion.find_by(id: notificacion_id)
    return unless notificacion

    user = notificacion.user
    badge_count = user.notificaciones.no_leidas.count

    payload = {
      title: notificacion.titulo,
      body:  notificacion.cuerpo || "",
      url:   notificacion.url || "/dashboard",
      badge_count: badge_count,
      tag:   "#{notificacion.tipo}_#{notificacion.metadata['sender_id'] || notificacion.id}"
    }.to_json

    vapid = Rails.application.config.x.vapid

    user.push_subscriptions.find_each do |sub|
      WebPush.payload_send(
        message:  payload,
        endpoint: sub.endpoint,
        p256dh:   sub.p256dh,
        auth:     sub.auth,
        vapid: {
          subject:     vapid[:subject],
          public_key:  vapid[:public_key],
          private_key: vapid[:private_key]
        },
        ttl: 86_400
      )
    rescue WebPush::ExpiredSubscription
      sub.destroy
    rescue WebPush::ResponseError => e
      Rails.logger.warn("Push failed for sub #{sub.id}: #{e.message}")
    end
  end
end
