# Segundo despliegue de devise_invitable 3 (PR #126): las invitaciones viven en devise_invitations desde
# 20261123015837, que las copió y dejó estas columnas para poder volver a la 2.x. Se borran cuando la 3.x lleva unos
# días estable. Sin marca de rollback compatible: la 2.x no arranca sin ellas, así que bin/rollback para (salida 3).
# Volver atrás con `down` recrea las columnas vacías, no sus datos (están en devise_invitations).
# config/deploy/asus/vuelta/20261123015837.sql se queda: con --aceptar-base-nueva hacia la 2.x falla sin estas
# columnas, en una transacción y antes de cambiar de imagen, así que esa vuelta para sin tocar nada.
class RemoveOldInvitationColumnsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :invitation_token, unique: true, name: "index_users_on_invitation_token"
    remove_index :users, :invited_by_id, name: "index_users_on_invited_by_id"
    remove_index :users, %i[invited_by_type invited_by_id], name: "index_users_on_invited_by"
    remove_column :users, :invitation_token, :string
    remove_column :users, :invitation_created_at, :datetime
    remove_column :users, :invitation_sent_at, :datetime
    remove_column :users, :invitation_accepted_at, :datetime
    remove_column :users, :invited_by_type, :string
    remove_column :users, :invited_by_id, :bigint
  end
end
