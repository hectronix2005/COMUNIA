require "test_helper"

# config/deploy/asus/vuelta/20261123015837.sql: lo que ejecuta bin/rollback antes de volver a devise_invitable 2.x.
# Pone al día las columnas viejas de users (que la 3.x ignora) con lo que la 3.x cerró en devise_invitations.
class VueltaDeviseInvitationsTest < ActiveSupport::TestCase
  include DenunciasPrueba

  SQL = Rails.root.join("config/deploy/asus/vuelta/20261123015837.sql").read

  # Lo que la 2.x ve en users (columnas ignoradas por el modelo).
  def columnas_viejas(user)
    User.connection.select_one(User.sanitize_sql(["SELECT invitation_token, invitation_accepted_at FROM users WHERE id = ?",
                                                   user.id]))
  end

  def token_viejo!(user, token, aceptada: nil)
    User.connection.execute(User.sanitize_sql(["UPDATE users SET invitation_token = ?, invitation_created_at = ?, " \
                                               "invitation_accepted_at = ? WHERE id = ?",
                                               token, 3.days.ago, aceptada, user.id]))
  end

  def invitacion!(user, token, aceptada: nil, superseded: nil, revocada: nil)
    DeviseInvitable::Invitation.insert_all!([{ invitation_token: token, invitation_created_at: 3.days.ago,
                                               invitation_sent_at: 3.days.ago, invitation_accepted_at: aceptada,
                                               superseded_at: superseded, revoked_at: revocada,
                                               invite_key: { "id" => user.id }, invite_key_digest: "d#{user.id}",
                                               invitable_type: "User", invitable_id: user.id,
                                               created_at: 3.days.ago, updated_at: Time.current }])
  end

  test "cierra en users lo aceptado, reinvitado o anulado con la 3.x, y deja lo que sigue pendiente" do
    acepto, reinvitado, anulado, pendiente, nuevo, sin_nada = %w[Acepto Reinvitado Anulado Pendiente Nuevo Nada].map { vecino(_1) }
    aceptada = 1.day.ago.change(usec: 0)
    token_viejo!(acepto, "viejo-a")
    invitacion!(acepto, "viejo-a", aceptada:)
    token_viejo!(reinvitado, "viejo-r")
    invitacion!(reinvitado, "viejo-r", superseded: 1.day.ago)
    invitacion!(reinvitado, "nuevo-r")
    token_viejo!(anulado, "viejo-n")
    invitacion!(anulado, nil, revocada: 1.day.ago)
    token_viejo!(pendiente, "viejo-p")
    invitacion!(pendiente, "viejo-p")
    invitacion!(nuevo, "solo-3x")

    2.times { User.connection.execute(SQL) } # repetirlo no cambia nada

    assert_nil columnas_viejas(acepto)["invitation_token"], "la 2.x lo dejaría fuera y el enlace volvería a valer"
    assert_equal aceptada, columnas_viejas(acepto)["invitation_accepted_at"]
    assert_nil columnas_viejas(reinvitado)["invitation_token"], "el enlace reemplazado no revive"
    assert_nil columnas_viejas(anulado)["invitation_token"], "el enlace anulado no revive"
    assert_equal "viejo-p", columnas_viejas(pendiente)["invitation_token"], "sigue pendiente en las dos versiones"
    assert_nil columnas_viejas(pendiente)["invitation_accepted_at"]
    assert_nil columnas_viejas(nuevo)["invitation_token"], "lo de la 3.x no pasa a users"
    assert_nil columnas_viejas(sin_nada)["invitation_token"]
  end
end
