# Aceptar la invitación que un admin generó desde la ficha del miembro: el miembro elige su contraseña
# y entra. El token caduca a los 7 días y sirve una sola vez (Devise guarda solo su resumen).
class InvitacionesController < Devise::InvitationsController
  after_action -> { response.set_header("Cache-Control", "no-store") }, only: :edit

  protected

  def after_accept_path_for(_resource)
    bienvenida_path
  end
end
