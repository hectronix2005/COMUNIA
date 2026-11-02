# Lo publicado en una sombrilla: comentar una publicación, reportar, ocultar y volver a mostrar (moderadores) y
# borrar (su autor o un moderador). El tipo sale de una lista blanca; lo de una sombrilla ajena es un 404.
class SombrillaContenidosController < ApplicationController
  TIPOS = {
    "publicacion" => SombrillaPublicacion, "comentario" => SombrillaComentario,
    "evento" => SombrillaEvento, "noticia" => Noticia
  }.freeze

  before_action :cargar

  def comentar
    raise ActiveRecord::RecordNotFound unless @registro.is_a?(SombrillaPublicacion)
    return volver(alert: "Comenta quien es de una comunidad de #{@sombrilla.nombre}.") unless @comunidad
    return volver(alert: "Antes de comentar, elige cómo quieres aparecer.") unless current_user.visibilidad_sombrilla

    comentario = @registro.comentarios.new(user: current_user, comunidad: @comunidad, contenido: params[:contenido].to_s.strip)
    comentario.save ? volver : volver(alert: comentario.errors.full_messages.to_sentence)
  end

  def reportar
    raise ActiveRecord::RecordNotFound if @registro.is_a?(Noticia)
    return volver(alert: "Reporta quien es de una comunidad de #{@sombrilla.nombre}.") unless @comunidad

    oculto = @registro.reportar!(current_user, @comunidad)
    volver(notice: oculto ? "Gracias. Lo reportaron vecinos de varias comunidades y quedó oculto." : "Gracias, quedó reportado.")
  end

  def ocultar = cambiar_oculta(true)
  def mostrar = cambiar_oculta(false)

  def eliminar
    raise ActiveRecord::RecordNotFound if @registro.is_a?(Noticia)
    return head(:forbidden) unless @modera || @registro.user_id == current_user.id

    @registro.destroy!
    volver(notice: "Eliminado.")
  end

  private

  def cargar
    clase = TIPOS.fetch(params[:tipo]) { raise ActiveRecord::RecordNotFound }
    @registro = clase.find(params[:id])
    @sombrilla = @registro.is_a?(Noticia) ? @registro.sombrilla : @registro.sombrilla_de
    raise ActiveRecord::RecordNotFound unless @sombrilla&.accesible_para?(current_user)

    @modera = @sombrilla.modera?(current_user)
    raise ActiveRecord::RecordNotFound if @registro.oculta && !@modera

    @comunidad = @sombrilla.comunidad_de(current_user)
  end

  def cambiar_oculta(valor)
    return head(:forbidden) unless @modera

    @registro.update!(oculta: valor)
    volver(notice: valor ? "Oculto: solo lo ven los moderadores." : "Visible otra vez.")
  end

  def volver(**mensaje)
    redirect_back fallback_location: sombrilla_path(@sombrilla), **mensaje
  end
end
