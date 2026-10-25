class PublicacionesController < ApplicationController
  def index
    @publicaciones = Publicacion.de_logias(logia_ids_visibles)
                                .recientes
                                .includes(:user, :logia, :publicacion_comentarios, :publicacion_likes, imagenes_attachments: :blob)
                                .page(params[:page]).per(15)
    @nueva = Publicacion.new
  end

  def create
    @pub = Publicacion.new(publicacion_params)
    @pub.user = current_user
    @pub.logia = current_logia

    if @pub.save
      redirect_to publicaciones_path, notice: "Publicación creada."
    else
      @publicaciones = Publicacion.de_logias(logia_ids_visibles).recientes
                                  .includes(:user, :logia).page(1).per(15)
      @nueva = @pub
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @pub = publicacion
    return head(:forbidden) unless @pub.user_id == current_user.id || modera?(@pub)
    @pub.destroy
    redirect_to publicaciones_path, notice: "Publicación eliminada."
  end

  def toggle_like
    @pub = publicacion
    like = @pub.publicacion_likes.find_by(user: current_user)
    if like
      like.destroy
    else
      @pub.publicacion_likes.create!(user: current_user)
    end
    redirect_back fallback_location: publicaciones_path
  end

  def comentar
    @pub = publicacion
    @pub.publicacion_comentarios.create!(user: current_user, contenido: params[:contenido])
    redirect_back fallback_location: publicaciones_path
  end

  def toggle_pin
    @pub = publicacion
    return head(:forbidden) unless modera?(@pub)
    @pub.update!(fijada: !@pub.fijada)
    redirect_back fallback_location: publicaciones_path
  end

  private

  def publicacion_params
    params.require(:publicacion).permit(:contenido, imagenes: [])
  end

  def publicacion
    Publicacion.de_logias(logia_ids_visibles).find(params[:id])
  end
end
