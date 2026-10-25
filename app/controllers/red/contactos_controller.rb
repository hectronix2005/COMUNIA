module Red
  # Contacto sin cuenta a una publicación pública. Quien escribe deja su nombre y su propio medio de
  # contacto (cifrado; se borra a los 90 días) y nunca ve los datos del autor. Captcha, consentimiento
  # y límite por IP (config/initializers/rack_attack.rb).
  class ContactosController < BaseController
    publico only: %i[new create]

    before_action :cargar_publicacion

    POR_PUBLICACION_DIA = 20

    def new; end

    def create
      @nombre, @contacto, @cuerpo = texto(:nombre, 60), texto(:contacto, 120), texto(:cuerpo, 2000)
      return volver("Verifica que no eres un robot.") unless captcha_disponible? && captcha_valido?
      return volver("Para enviar el mensaje acepta el tratamiento de tus datos.") unless params[:acepto] == "1"
      return volver("Deja un correo o un teléfono válido para que te respondan.") unless contacto_valido?(@contacto)
      return volver("Escribe tu nombre y el mensaje.") if @nombre.to_s.length < 2 || @cuerpo.to_s.length < 5
      return volver("Esta publicación recibió muchos mensajes hoy. Inténtalo mañana.") if
        @publicacion.conversaciones.where(iniciador_id: nil, created_at: 24.hours.ago..).count >= POR_PUBLICACION_DIA

      conversacion = Conversacion.create!(destinatario: @publicacion.user, publicacion: @publicacion, nombre_externo: @nombre,
                                          contacto_externo: @contacto)
      conversacion.mensajes.create!(cuerpo: @cuerpo)
      Red.avisar(@publicacion.user, "Mensaje de #{@nombre} (sin cuenta)", @cuerpo.truncate(80),
                 red_conversacion_path(conversacion), tipo: "red_mensaje")
      redirect_to red_publicacion_path(@publicacion), notice: "Mensaje enviado. Te responderán por el medio que dejaste."
    end

    private

    def cargar_publicacion
      return redirect_to(red_publicacion_path(params[:token].to_s)) if user_signed_in?
      @publicacion = Publicacion.visible(params[:token].to_s, nil)
      no_encontrado unless @publicacion
    end

    def contacto_valido?(c)
      c.present? && (c.match?(URI::MailTo::EMAIL_REGEXP) || c.gsub(/[\s().-]/, "").match?(/\A\+?\d{7,15}\z/))
    end

    def volver(mensaje)
      flash.now[:alert] = mensaje
      render :new, status: :unprocessable_content
    end
  end
end
