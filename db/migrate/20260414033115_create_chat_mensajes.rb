class CreateChatMensajes < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_mensajes do |t|
      t.references :logia, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :contenido

      t.timestamps
    end
  end
end
