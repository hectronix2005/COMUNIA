# Primer ingreso de quien entró con el celular y una contraseña temporal (User#debe_completar_datos): elige su
# contraseña y da sus datos reales (correo, apellidos, cédula y su programa o grupo). Hasta entonces el resto de
# la app lo trae aquí (ApplicationController#exigir_datos_completos).
class CompletarDatosController < ApplicationController
  before_action -> { redirect_to dashboard_path unless current_user.debe_completar_datos? }
  after_action -> { response.set_header("Cache-Control", "no-store") }

  def edit
    @user = current_user
    @miembro = current_user.miembro
  end

  def update
    @user = current_user
    @miembro = current_user.miembro
    datos = params.expect(user: [:nombre, :apellido, :email, :cedula, :programa, :password, :password_confirmation])

    @user.assign_attributes(datos.slice(:nombre, :apellido, :email, :password, :password_confirmation).merge(
                              debe_completar_datos: false, completando_datos: true))
    @miembro&.assign_attributes(cedula: datos[:cedula], bio: datos[:programa].to_s.strip.presence)

    if datos_validos?(datos)
      User.transaction do
        @user.save!
        @miembro&.save!
      end
      bypass_sign_in(@user) # cambiar la contraseña cierra la sesión: se mantiene la de ahora
      redirect_to dashboard_path, notice: "¡Listo, #{@user.nombre}! Ya puedes usar #{current_logia.nombre_display}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Todos obligatorios, y la contraseña no puede ser la temporal que se mandó por WhatsApp. Los errores de la
  # ficha (una cédula repetida) se enseñan con los de la cuenta.
  def datos_validos?(datos)
    @miembro&.user = @user # la ficha ve que ya no le falta nada a la cuenta: la cédula pasa a ser obligatoria
    @user.valid?
    @miembro&.valid?
    @user.errors.add(:apellido, :blank) if datos[:apellido].blank?
    @user.errors.add(:email, :blank) if datos[:email].blank?
    @user.errors.add(:base, "#{etiqueta_programa} no puede estar en blanco") if datos[:programa].blank?
    @user.errors.add(:password, :blank) if datos[:password].blank?
    @user.errors.add(:password, "debe ser distinta de la temporal") if datos[:password].present? &&
                                                                    User.find(@user.id).valid_password?(datos[:password])
    @miembro&.errors&.each { @user.errors.add(:base, _1.full_message) }
    @user.errors.none?
  end

  helper_method def etiqueta_programa
    current_logia.organizacion.categoria&.nombre == "Universidad" ? "Programa y cohorte" : "Grupo o promoción"
  end
end
