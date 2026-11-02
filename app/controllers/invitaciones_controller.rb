# Aceptar la invitación que un admin generó desde la ficha del miembro: el miembro elige su contraseña
# y entra. El token caduca a los 7 días y sirve una sola vez (Devise guarda solo su resumen).
class InvitacionesController < Devise::InvitationsController
  after_action -> { response.set_header("Cache-Control", "no-store") }, only: :edit

  # Con el enlace ya usado o caducado no se vuelve a pintar el formulario: si la respuesta al primer envío no llegó
  # al teléfono, la contraseña ya quedó guardada y la persona debe ir a entrar con ella, no reintentar sin salida.
  def update
    super do |resource|
      if resource.errors.include?(:invitation_token)
        set_flash_message(:alert, :invitation_token_invalid)
        return redirect_to(invalid_token_path_for(resource_name), status: :see_other)
      end
    end
  end

  protected

  # El rastreo apunta de quién es la invitación que se abrió (el token no se guarda): así el resumen diario dice
  # «abrió la invitación, no la aceptó» aunque aún no tenga sesión.
  def rastreo_extra
    action_name == "edit" && resource&.persisted? ? { invitado_id: resource.id } : {}
  end

  def after_accept_path_for(_resource)
    bienvenida_path
  end
end
