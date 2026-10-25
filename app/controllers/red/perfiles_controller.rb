module Red
  # Perfil público de una persona: su ficha, lo que publica y sus reseñas. Sin cuenta solo se ven los
  # perfiles que eligieron aparecer en la búsqueda pública. Lo que no se puede ver da el mismo 404 que
  # lo que no existe.
  class PerfilesController < BaseController
    publico only: %i[show hoja_de_vida]

    before_action :cargar_perfil

    def show
      @ficha = Ficha.new(@perfil)
      @publicaciones = Publicacion.tablon_para(current_user, mis_comunidad_ids).where(user_id: @perfil.user_id)
                                  .order(created_at: :desc).limit(20)
      @resenas = Resena.where(sujeto_id: @perfil.user_id).order(created_at: :desc).limit(10)
      @propio = current_user && @perfil.user_id == current_user.id
    end

    # Se sirve desde aquí (y no con un enlace firmado de ActiveStorage) para que la visibilidad se
    # compruebe en cada descarga.
    def hoja_de_vida
      return no_encontrado unless @perfil.hoja_de_vida.attached?
      send_data @perfil.hoja_de_vida.download, filename: "hoja-de-vida-#{@perfil.token[0, 6]}.pdf",
                                                type: "application/pdf", disposition: "inline"
    end

    private

    def cargar_perfil
      base = current_user ? Perfil.visibles_para(current_user, mis_comunidad_ids).activos : Perfil.buscables_sin_cuenta
      @perfil = base.find_by(token: params[:token].to_s) || (moderador? && Perfil.find_by(token: params[:token].to_s))
      no_encontrado unless @perfil
    end
  end
end
