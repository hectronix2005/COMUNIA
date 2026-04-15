class AddCanalToChatMensajes < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_mensajes, :canal, :string, default: "logia", null: false
    add_index  :chat_mensajes, :canal
  end
end
