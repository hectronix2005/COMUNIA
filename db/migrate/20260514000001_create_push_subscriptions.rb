class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text       :endpoint, null: false
      t.text       :p256dh,   null: false
      t.text       :auth,     null: false
      t.string     :user_agent
      t.timestamps
    end

    add_index :push_subscriptions, [:user_id, :endpoint], unique: true
  end
end
