class NegocioConversacionesController < ApplicationController
  before_action :set_conversacion, only: [:show]

  def index
    @conversaciones = NegocioConversacion
                        .de_usuario(current_user)
                        .includes(:negocio_anuncio, :comprador, :vendedor, :mensajes)
                        .ordenadas
  end

  def show
    authorize_conversacion!
    @mensajes = @conversacion.mensajes.includes(:user)
    @mensajes.where.not(user_id: current_user.id).where(leido: false).update_all(leido: true)
    @mensaje = NegocioMensaje.new
  end

  def create
    anuncio = NegocioAnuncio.find_by_slug_or_id(params[:negocio_id] || params[:id])
    if anuncio.user_id == current_user.id
      redirect_to negocio_path(anuncio), alert: "No puedes iniciar conversación en tu propio anuncio."
      return
    end

    conv = NegocioConversacion.find_or_create_by!(
      negocio_anuncio: anuncio,
      comprador:       current_user
    ) { |c| c.vendedor = anuncio.user }

    if params[:cuerpo].present?
      conv.mensajes.create!(user: current_user, cuerpo: params[:cuerpo])
    end

    redirect_to negocio_conversacion_path(conv)
  end

  private

  def set_conversacion
    @conversacion = NegocioConversacion.find(params[:id])
  end

  def authorize_conversacion!
    unless [@conversacion.comprador_id, @conversacion.vendedor_id].include?(current_user.id) ||
           current_user.rol_ref&.es_super_admin?
      redirect_to negocio_conversaciones_path, alert: "Sin permiso."
    end
  end
end
