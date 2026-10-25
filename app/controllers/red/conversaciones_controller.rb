module Red
  # Mensajería intermediada. Nadie ve el teléfono ni el correo del otro hasta que este pulsa
  # «compartir mi contacto». Las reseñas solo se dejan tras una conversación real (Conversacion#resenable_por?).
  class ConversacionesController < BaseController
    before_action :exigir_perfil, only: %i[create escribir]
    before_action :cargar_conversacion, except: %i[index create]

    NUEVAS_POR_DIA = 20
    NUEVAS_POR_DIA_CUARENTENA = 5

    def index
      @conversaciones = Conversacion.de(current_user).includes(:publicacion, iniciador: :red_perfil, destinatario: :red_perfil)
                                    .order(Arel.sql("ultimo_mensaje_at DESC NULLS LAST"), id: :desc).page(params[:page]).per(30)
      ids = @conversaciones.map(&:id)
      @no_leidos = Mensaje.where(conversacion_id: ids, leido_at: nil).where("user_id IS NULL OR user_id <> ?", current_user.id)
                          .group(:conversacion_id).count
    end

    def show
      @conversacion.mensajes.where(leido_at: nil).where("user_id IS NULL OR user_id <> ?", current_user.id).update_all(leido_at: Time.current)
      @otro = @conversacion.externa? ? nil : @conversacion.otro(current_user)
      @ficha_otro = @otro&.red_perfil && Ficha.new(@otro.red_perfil)
      @puede_resenar = @conversacion.resenable_por?(current_user)
    end

    # Primer mensaje a una persona (desde su perfil o desde una publicación suya).
    def create
      destino = Perfil.visibles_para(current_user, mis_comunidad_ids).activos.find_by(token: params[:token].to_s)
      return no_encontrado unless destino
      return redirect_back(fallback_location: red_inicio_path, alert: "No puedes escribirte a ti mismo.") if destino.user_id == current_user.id
      cuerpo = texto(:cuerpo, 2000)
      return redirect_back(fallback_location: red_perfil_path(destino), alert: "Escribe un mensaje.") if cuerpo.blank?
      return redirect_back(fallback_location: red_perfil_path(destino), alert: "No puedes escribir a esta persona.") if
        Bloqueo.entre?(current_user, destino.user) || mi_perfil.suspendido?

      publicacion = (Publicacion.visible(texto(:publicacion, 30), current_user) if texto(:publicacion, 30).present?)
      publicacion = nil unless publicacion&.user_id == destino.user_id
      conversacion = Conversacion.find_by(iniciador_id: current_user.id, destinatario_id: destino.user_id, publicacion_id: publicacion&.id)
      unless conversacion
        return redirect_back(fallback_location: red_perfil_path(destino), alert: "Has abierto muchas conversaciones hoy. Vuelve mañana.") if
          demasiadas_nuevas?
        conversacion = Conversacion.create!(iniciador: current_user, destinatario: destino.user, publicacion: publicacion)
      end
      return redirect_to(red_conversacion_path(conversacion), alert: "Esta conversación está cerrada.") unless conversacion.estado == "abierta"
      enviar(conversacion, cuerpo)
      redirect_to red_conversacion_path(conversacion), notice: "Mensaje enviado."
    end

    def escribir
      return volver("Esta conversación está cerrada.") unless @conversacion.estado == "abierta"
      return volver("A quien escribió sin cuenta respóndele por el medio que dejó.") if @conversacion.externa?
      return volver("No puedes escribir a esta persona.") if Bloqueo.entre?(current_user, @conversacion.otro(current_user))
      cuerpo = texto(:cuerpo, 2000)
      return volver("Escribe un mensaje.") if cuerpo.blank?
      enviar(@conversacion, cuerpo)
      redirect_to red_conversacion_path(@conversacion, anchor: "fin")
    end

    def compartir_contacto
      return volver("Esta conversación está cerrada.") unless @conversacion.estado == "abierta"
      return volver("Aquí no hace falta: ya tienes su medio de contacto.") if @conversacion.externa?
      datos = [("Teléfono: #{mi_perfil.contacto_telefono}" if mi_perfil&.contacto_telefono.present?),
               ("Correo: #{mi_perfil.contacto_correo}" if mi_perfil&.contacto_correo.present?)].compact
      return volver("Primero añade tu teléfono o correo en tu perfil.") if datos.empty?
      enviar(@conversacion, datos.join(" · "), tipo: "contacto_compartido")
      redirect_to red_conversacion_path(@conversacion, anchor: "fin"), notice: "Compartiste tu contacto."
    end

    def bloquear
      unless @conversacion.externa?
        Bloqueo.find_or_create_by!(user: current_user, bloqueado: @conversacion.otro(current_user))
      end
      @conversacion.update!(estado: "bloqueada")
      redirect_to red_conversaciones_path, notice: "Bloqueado. No recibirás más mensajes de esta conversación."
    end

    def resena
      return volver("Aún no puedes dejar reseña aquí: hace falta una conversación de al menos un día con mensajes de los dos.") unless
        @conversacion.resenable_por?(current_user)
      sujeto = @conversacion.otro(current_user)
      r = Resena.new(conversacion: @conversacion, autor: current_user, sujeto: sujeto, puntaje: texto(:puntaje, 1).to_i,
                     comentario: texto(:comentario, 1000))
      return volver(r.errors.full_messages.to_sentence) unless r.save
      Red.avisar(sujeto, "Recibiste una reseña", "#{r.puntaje} de 5", sujeto.red_perfil ? red_perfil_path(sujeto.red_perfil) : nil)
      redirect_to red_conversacion_path(@conversacion), notice: "Gracias por tu reseña."
    end

    private

    def cargar_conversacion
      @conversacion = Conversacion.find_by(token: params[:token].to_s)
      no_encontrado unless @conversacion&.participa?(current_user)
    end

    def demasiadas_nuevas?
      tope = mi_perfil.en_cuarentena? ? NUEVAS_POR_DIA_CUARENTENA : NUEVAS_POR_DIA
      Conversacion.where(iniciador_id: current_user.id, created_at: 24.hours.ago..).count >= tope
    end

    def enviar(conversacion, cuerpo, tipo: "texto")
      conversacion.mensajes.create!(user: current_user, cuerpo: cuerpo, tipo: tipo)
      otro = conversacion.otro(current_user)
      return unless otro
      nombre = mi_perfil&.nombre_publico || current_user.nombre_corto
      Red.avisar(otro, tipo == "texto" ? "Mensaje de #{nombre}" : "#{nombre} te compartió su contacto",
                 cuerpo.truncate(80), red_conversacion_path(conversacion), tipo: "red_mensaje")
    end

    def volver(mensaje)
      redirect_to red_conversacion_path(@conversacion), alert: mensaje
    end
  end
end
