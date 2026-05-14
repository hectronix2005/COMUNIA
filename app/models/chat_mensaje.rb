class ChatMensaje < ApplicationRecord
  CANALES = %w[logia tenant dm].freeze
  REACCIONES_PERMITIDAS = %w[👍 ❤️ 😂 😮 😢 🙏].freeze

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
  scope :unread_dm_for, ->(user_id) {
    where(canal: "dm", destinatario_id: user_id, leido_at: nil)
  }

  after_create_commit :broadcast_mensaje
  after_create_commit :notificar_destinatarios

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

  def marcar_leido!(lector)
    return unless dm? && destinatario_id == lector.id && leido_at.nil?
    update_column(:leido_at, Time.current)
  end

  def toggle_reaccion!(usr, emoji)
    return unless REACCIONES_PERMITIDAS.include?(emoji)
    r = reacciones.dup
    r[emoji] ||= []
    if r[emoji].include?(usr.id)
      r[emoji].delete(usr.id)
      r.delete(emoji) if r[emoji].empty?
    else
      r[emoji] << usr.id
    end
    update!(reacciones: r)
    broadcast_replace_to(
      stream_name,
      target:  "msg-reacciones-#{id}",
      partial: "chat/mensaje_reacciones",
      locals:  { mensaje: self }
    )
  end

  def leido?
    leido_at.present?
  end

  # Hash { partner_user_id => ChatMensaje }
  def self.ultimo_mensaje_dm(user_id)
    sql = <<~SQL
      SELECT DISTINCT ON (partner_id) *
      FROM (
        SELECT *,
          CASE WHEN user_id = #{user_id.to_i} THEN destinatario_id ELSE user_id END AS partner_id
        FROM chat_mensajes
        WHERE canal = 'dm' AND (user_id = #{user_id.to_i} OR destinatario_id = #{user_id.to_i})
      ) sub
      ORDER BY partner_id, created_at DESC
    SQL
    find_by_sql(sql).index_by { |m| m[:partner_id] }
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

  def notificar_destinatarios
    NotificarChatJob.perform_later(id)
  end
end
