class NegocioMensaje < ApplicationRecord
  belongs_to :negocio_conversacion
  belongs_to :user

  validates :cuerpo, presence: true, length: { maximum: 5000 }

  after_create_commit :actualizar_conversacion
  after_create_commit :broadcast_mensaje

  private

  def actualizar_conversacion
    negocio_conversacion.update_column(:ultimo_mensaje_at, created_at)
  end

  def broadcast_mensaje
    broadcast_append_to(
      [negocio_conversacion, :mensajes],
      target: "mensajes-list",
      partial: "negocio_mensajes/mensaje",
      locals: { mensaje: self, current_user: nil }
    )
  end
end
