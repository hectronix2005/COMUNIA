class ChatMensaje < ApplicationRecord
  CANALES = %w[logia tenant dm].freeze

  belongs_to :logia
  belongs_to :user
  belongs_to :destinatario, class_name: "User", optional: true

  validates :contenido, presence: true, length: { maximum: 1000 }
  validates :canal, inclusion: { in: CANALES }

  scope :canal_logia,  -> { where(canal: "logia") }
  scope :canal_tenant, -> { where(canal: "tenant") }
  scope :dm_entre, ->(a, b) {
    where(canal: "dm")
      .where(
        "(user_id = ? AND destinatario_id = ?) OR (user_id = ? AND destinatario_id = ?)",
        a, b, b, a
      )
  }

  after_create_commit :broadcast_mensaje

  def dm?
    canal == "dm"
  end

  def stream_name
    case canal
    when "dm"     then "chat_dm_#{[user_id, destinatario_id].sort.join('_')}"
    when "tenant" then "chat_tenant_#{logia_id}"
    else               "chat_logia_#{logia_id}"
    end
  end

  private

  def broadcast_mensaje
    broadcast_append_to(
      stream_name,
      target:  "chat-mensajes",
      partial: "chat/mensaje",
      locals:  { mensaje: self }
    )
  end
end
