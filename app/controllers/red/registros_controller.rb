module Red
  # Registro público de cuentas de la red. La cuenta es de Devise (contraseña con bcrypt, bloqueo por
  # intentos); aquí solo se valida el formulario, el captcha y el consentimiento. El rol no viene del
  # formulario: toda cuenta creada aquí es `solo_red` y `miembro`.
  class RegistrosController < BaseController
    publico only: %i[new create]
    before_action :fuera_si_ya_entro

    def new
      @user = User.new
    end

    def create
      @user = User.new(nombre: texto(:nombre, 60), apellido: texto(:apellido, 60), email: texto(:email, 120)&.downcase,
                       password: texto(:password, 128), password_confirmation: texto(:password_confirmation, 128),
                       username: "r#{SecureRandom.hex(6)}", solo_red: true, rol: :miembro)
      return volver("Acepta la política de datos para crear tu cuenta.") unless params[:acepto] == "1"
      return volver("Hoy no podemos crear cuentas nuevas. Inténtalo más tarde.") unless captcha_disponible?
      return volver("Confirma que no eres un robot.") unless captcha_valido?
      return volver(@user.errors.full_messages.to_sentence) unless @user.save

      sign_in(@user)
      redirect_to red_bienvenida_path, notice: "Cuenta creada. Ahora tu perfil."
    end

    private

    def fuera_si_ya_entro
      redirect_to red_inicio_path if user_signed_in?
    end

    def volver(mensaje)
      flash.now[:alert] = mensaje
      @user.password = @user.password_confirmation = nil
      render :new, status: :unprocessable_content
    end
  end
end
