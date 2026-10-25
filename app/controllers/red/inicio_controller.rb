module Red
  # Portada: sin cuenta, qué es la red y el buscador; con cuenta, el tablón de lo que ve esa persona.
  class InicioController < BaseController
    publico only: :index

    def index
      return render(:portada) unless user_signed_in?
      return redirect_to(red_bienvenida_path) unless mi_perfil

      @publicaciones = Publicacion.tablon_para(current_user, mis_comunidad_ids)
                                  .where.not(user_id: current_user.id)
                                  .includes(user: %i[red_perfil red_confianza])
                                  .order(created_at: :desc).limit(20)
      @fichas = Ficha.de_lista(@publicaciones.map(&:perfil))
    end
  end
end
