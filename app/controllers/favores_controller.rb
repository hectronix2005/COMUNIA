# «Pido / ofrezco» entre vecinos (Favor). Lo ve toda la comunidad (la raíz y sus grupos). Un «pido» avisa al momento
# a todos (AvisarFavorJob); un «ofrezco» espera al resumen de los lunes. «Puedo ayudar» abre el chat privado con el
# autor y le deja el primer mensaje; el autor lo marca resuelto y, si elige a quien ayudó, le llegan las gracias.
class FavoresController < ApplicationController
  before_action { requiere_modulo!(:pido_ofrezco) }
  before_action :cargar_favor, only: %i[show ayudar resolver cerrar]

  def index
    @tipo = params[:tipo].presence_in(Favor::TIPOS)
    base = favores.vigentes.includes(:user).recientes
    @favores = @tipo ? base.where(tipo: @tipo) : base
    @mios = favores.where(user: current_user).where.not(id: @favores.where(user: current_user).select(:id))
                   .includes(:ayudante).recientes.limit(10)
  end

  def show
    @respuestas = @favor.favor_respuestas.includes(:user).order(:created_at) if mio?
  end

  def new
    @favor = Favor.new(tipo: params[:tipo].presence_in(Favor::TIPOS) || "pido")
  end

  def create
    @favor = Favor.new(favor_params.merge(user: current_user, logia: current_logia.organizacion))
    if @favor.save
      AvisarFavorJob.perform_later(@favor.id) if @favor.pido?
      aviso = @favor.pido? ? "Listo: tus vecinos ya saben lo que necesitas." : "Listo: tu oferta sale en «Pido / ofrezco» y en el resumen del lunes."
      redirect_to favor_path(@favor), notice: aviso
    else
      render :new, status: :unprocessable_entity
    end
  end

  # «Puedo ayudar»: una vez por persona; deja el primer mensaje en el chat privado con el autor y lo abre.
  def ayudar
    return redirect_to(favor_path(@favor), alert: "Esto ya no está abierto.") unless @favor.vigente?
    return redirect_to(favor_path(@favor)) if mio?

    unless @favor.respondido_por?(current_user)
      @favor.favor_respuestas.create!(user: current_user)
      texto = @favor.pido? ? "Hola, puedo ayudarte con «#{@favor.titulo}»." : "Hola, me interesa lo que ofreces: «#{@favor.titulo}»."
      ChatMensaje.create!(logia: current_logia, user: current_user, contenido: texto, canal: "dm", destinatario: @favor.user)
    end
    redirect_to chat_path(con: @favor.user_id)
  end

  # Solo el autor. Si elige a alguien que respondió, le da las gracias con un aviso.
  def resolver
    return head(:forbidden) unless mio?
    return redirect_to(favor_path(@favor)) unless @favor.abierto?

    ayudante = @favor.ayudantes_posibles.find_by(id: params[:ayudante_id]) if params[:ayudante_id].present?
    @favor.resolver!(ayudante:)
    if ayudante
      NotificacionService.crear!(user: ayudante, tipo: "favor_gracias", titulo: "#{current_user.nombre_corto} te da las gracias",
                                 cuerpo: "Por ayudar con «#{@favor.titulo}».", url: "/favores/#{@favor.id}", logia: @favor.logia)
    end
    redirect_to favores_path, notice: ayudante ? "Resuelto. Le dimos las gracias a #{ayudante.nombre_corto}." : "Resuelto."
  end

  # El autor o quien modera la comunidad lo quita de la lista.
  def cerrar
    return head(:forbidden) unless mio? || modera?(@favor)

    @favor.update!(estado: "cerrado") if @favor.abierto?
    redirect_to favores_path, notice: "Cerrado: ya no sale en la lista."
  end

  private

  def favores = Favor.de_logias(logia_ids_de_la_organizacion)

  def cargar_favor
    @favor = favores.includes(:user).find(params[:id])
  end

  def mio? = @favor.user_id == current_user.id

  def favor_params
    params.require(:favor).permit(:tipo, :titulo, :detalle)
  end
end
