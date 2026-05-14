class CreateNotificaciones < ActiveRecord::Migration[8.0]
  def change
    create_table :notificaciones do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :logia, foreign_key: true
      t.string     :tipo,   null: false
      t.string     :titulo, null: false
      t.text       :cuerpo
      t.string     :url
      t.boolean    :leida,    null: false, default: false
      t.datetime   :leida_at
      t.jsonb      :metadata, default: {}
      t.timestamps
    end

    add_index :notificaciones, [:user_id, :leida, :created_at], order: { created_at: :desc }
  end
end
