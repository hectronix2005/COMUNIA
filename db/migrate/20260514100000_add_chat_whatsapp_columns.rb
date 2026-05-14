class AddChatWhatsappColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_mensajes, :leido_at, :datetime, null: true
    add_column :chat_mensajes, :reacciones, :jsonb, default: {}, null: false
    add_column :users, :last_seen_at, :datetime, null: true

    add_index :chat_mensajes, [:destinatario_id, :leido_at],
              where: "canal = 'dm' AND leido_at IS NULL",
              name: "index_chat_mensajes_unread_dm"
  end
end
