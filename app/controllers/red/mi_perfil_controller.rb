module Red
  # Mi perfil: crearlo (bienvenida, con el consentimiento de la Ley 1581), editarlo, exportar todos
  # mis datos de la red y borrarlos.
  class MiPerfilController < BaseController
    before_action :exigir_perfil, only: %i[edit update exportar destroy]

    def bienvenida
      return redirect_to(red_mi_perfil_path) if mi_perfil
      @perfil = Perfil.new(nombre_publico: current_user.nombre_corto, alcance: "mis_comunidades")
    end

    def crear
      return redirect_to(red_mi_perfil_path) if mi_perfil
      @perfil = current_user.build_red_perfil(datos_perfil.merge(politica_version: POLITICA_VERSION, acepto_tratamiento_at: Time.current))
      return volver(:bienvenida, "Para crear tu perfil acepta la política de tratamiento de datos.") unless params[:acepto] == "1"
      aplicar_alcance(@perfil)
      @perfil.onboarding_completado_at = Time.current
      return volver(:bienvenida, @perfil.errors.full_messages.to_sentence) unless @perfil.save
      CalculoConfianza.guardar!(current_user) # la primera foto (nivel 0 si aún no tiene comunidades)
      redirect_to(mis_comunidad_ids.empty? ? red_comunidades_path : red_inicio_path,
                  notice: mis_comunidad_ids.empty? ? "Perfil creado. Ahora únete a tu primera comunidad." : "Perfil creado.")
    end

    def edit
      @perfil = mi_perfil
    end

    def update
      @perfil = mi_perfil
      @perfil.assign_attributes(datos_perfil)
      aplicar_alcance(@perfil)
      if (archivo = params[:hoja_de_vida]).is_a?(ActionDispatch::Http::UploadedFile)
        @perfil.hoja_de_vida.attach(archivo)
      end
      @perfil.hoja_de_vida.purge_later if params[:quitar_hoja_de_vida] == "1" && @perfil.hoja_de_vida.attached?
      return volver(:edit, @perfil.errors.full_messages.to_sentence) unless @perfil.save
      redirect_to red_mi_perfil_path, notice: "Perfil guardado."
    end

    # Ley 1581, derecho de acceso: todo lo que la red guarda de mí, en JSON.
    def exportar
      send_data JSON.pretty_generate(Exportacion.de(current_user)), filename: "mis-datos-red-#{Date.current.iso8601}.json",
                                                                     type: "application/json", disposition: "attachment"
    end

    # Ley 1581, supresión. Borra perfil, publicaciones, membresías, conversaciones y reseñas propias.
    # Si la cuenta es solo de la red, se borra la cuenta entera.
    def destroy
      return volver(:edit, "Escribe BORRAR para confirmar.") unless params[:confirmacion].to_s.strip.casecmp?("borrar")
      solo_red = current_user.solo_red?
      Borrado.call(current_user)
      sign_out(current_user) if solo_red
      redirect_to red_inicio_path, notice: "Tus datos de la red se borraron."
    end

    private

    def datos_perfil
      { nombre_publico: texto(:nombre_publico, 60), titular: texto(:titular, 120), bio: texto(:bio, 2000),
        ciudad: texto(:ciudad, 60), habilidades: texto(:habilidades, 500),
        contacto_telefono: texto(:contacto_telefono, 20), contacto_correo: texto(:contacto_correo, 120),
        visible_publico: params[:visible_publico] == "1" }.compact.merge(visible_publico: params[:visible_publico] == "1")
    end

    def aplicar_alcance(perfil)
      alcance = texto(:alcance, 20)
      perfil.alcance = alcance if ConAlcance::ALCANCES.key?(alcance)
      perfil.comunidades_elegidas = Array(params[:comunidades]).grep(String) if perfil.alcance == "elegidas"
      perfil.visible_publico = false unless perfil.alcance == "publico"
    end

    def volver(vista, mensaje)
      @perfil ||= mi_perfil
      flash.now[:alert] = mensaje
      render vista, status: :unprocessable_content
    end
  end
end
