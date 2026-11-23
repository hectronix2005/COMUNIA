# rollback: compatible — copia y no borra; la 2.x arranca con esta base (probado sobre una copia de producción el
# 22-nov-2026) y config/deploy/asus/vuelta/20261123015837.sql le pone al día lo que la 3.x cerró.
# devise_invitable 3: las invitaciones salen de users a devise_invitations (generada con
# `rails g devise_invitable:upgrade User`). Copia cada invitación y DEJA las columnas viejas de users: User las
# ignora (ignored_columns) y se borran en un despliegue posterior. Así, si hay que volver a la versión anterior,
# arranca con esta base (bin/rollback --aceptar-base-nueva) sin restaurar la copia.
require "digest"

class UpgradeUsersDeviseInvitations < ActiveRecord::Migration[8.1]
  def up
    create_devise_invitations_table unless table_exists?(:devise_invitations)

    resource_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'users'
      self.inheritance_column = :_type_disabled
    end
    invitation_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'devise_invitations'
    end

    resource_class.where.not(invitation_created_at: nil).find_each do |resource|
      invite_key = resource.attributes.slice("id") # la misma clave que config.invite_key
      digest_components = invite_key.map { |key, value| [key.to_s, value.to_s] }.sort.flatten
      invitation_class.create!(
        invitation_token: resource.invitation_token,
        invitation_created_at: resource.invitation_created_at,
        # Los enlaces se generan con skip_invitation (van por WhatsApp), así que sent_at quedó vacío. La 2.x contaba
        # los 7 días desde invitation_created_at (y si no, sent_at) y la 3.x los cuenta desde sent_at: se copia la
        # fecha que usaba la 2.x, o todo enlace ya enviado nacería caducado al migrar.
        invitation_sent_at: resource.invitation_created_at || resource.invitation_sent_at,
        invitation_accepted_at: resource.invitation_accepted_at,
        # La 2.x solo bloqueaba con token; la 3.x, con cualquier invitación sin aceptar. Una sin token ni aceptar (no
        # hay ninguna en producción el 22-nov-2026) queda anulada para no dejar fuera a quien hoy entra.
        revoked_at: (Time.current if resource.invitation_token.nil? && resource.invitation_accepted_at.nil?),
        resource_created_at: resource.invitation_created_at,
        invite_key: invite_key,
        invite_key_digest: Digest::SHA256.hexdigest((['User'] + digest_components).join("\0")),
        invitable_type: 'User',
        invitable_id: resource.id,
        invited_by_type: resource.invited_by_type,
        invited_by_id: resource.invited_by_id,
        created_at: resource.invitation_created_at,
        updated_at: resource.invitation_accepted_at || resource.invitation_sent_at || resource.invitation_created_at
      )
    end
  end

  # Las columnas de users siguen ahí; borra TODAS las invitaciones de la tabla nueva, también las creadas con la 3.x.
  def down
    execute "DELETE FROM devise_invitations"
  end

  private

    def create_devise_invitations_table
      create_table :devise_invitations do |t|
        t.string :invitation_token
        t.datetime :invitation_created_at
        t.datetime :invitation_sent_at
        t.datetime :invitation_accepted_at
        t.datetime :superseded_at
        t.string :superseded_reason
        t.datetime :revoked_at
        t.datetime :resource_created_at
        t.json :invite_key, null: false, default: {}
        t.string :invite_key_digest, null: false
        t.references :invitable, polymorphic: true
        t.references :invited_by, polymorphic: true
        t.timestamps
      end
      add_index :devise_invitations, :invitation_token, unique: true
      add_index :devise_invitations, [:invitable_type, :invite_key_digest],
        name: 'index_devise_invitations_on_type_and_invite_key'
    end
end
