class AddDestinatarioToChatMensajes < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_mensajes, :destinatario_id, :integer
  end
end
