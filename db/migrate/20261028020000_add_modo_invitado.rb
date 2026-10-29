class AddModoInvitado < ActiveRecord::Migration[8.1]
  def change
    # La comunidad de demostración (Demo) y la cuenta compartida con la que se mira sin registrarse.
    add_column :logias, :demo, :boolean, default: false, null: false
    add_column :users, :invitado, :boolean, default: false, null: false
    add_index :logias, :demo, unique: true, where: "demo"
    add_index :users, :invitado, unique: true, where: "invitado"
  end
end
