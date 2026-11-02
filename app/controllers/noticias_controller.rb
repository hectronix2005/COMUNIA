# Noticias de internet sobre la comunidad (Noticia, ActualizarNoticiasJob). Las enciende y configura el admin de
# la comunidad, no el de un grupo (Héctor, 2-nov-2026); las ven todos sus miembros. El admin oculta las que no
# sirvan y puede volver a mostrarlas.
class NoticiasController < ApplicationController
  before_action :exigir_admin, except: :index

  def index
    @comunidad = comunidad
    @admin = admin_de_la_comunidad?
    unless @comunidad.noticias_activas
      return redirect_to(configuracion_noticias_path) if @admin

      return redirect_to(dashboard_path, alert: "Tu comunidad no tiene Noticias.")
    end
    @noticias = @comunidad.noticias.recientes
    @noticias = @noticias.visibles unless @admin && params[:ocultas] == "1"
    @noticias = @noticias.page(params[:page]).per(20)
    @ocultas = @comunidad.noticias.where(oculta: true).count if @admin
  end

  def configuracion
    @comunidad = comunidad
    @comunidad.noticias_busquedas = [@comunidad.nombre] if @comunidad.noticias_busquedas.empty?
  end

  def guardar
    @comunidad = comunidad
    datos = params.fetch(:noticias, {})
    @comunidad.noticias_activas = datos[:activas] == "1"
    @comunidad.noticias_busquedas = Array(datos[:busquedas]).grep(String).first(Logia::BUSQUEDAS_NOTICIAS)
    if @comunidad.save
      ActualizarNoticiasJob.perform_later(@comunidad.id) if @comunidad.noticias_activas
      aviso = @comunidad.noticias_activas ? "Noticias encendidas. Las primeras llegan en un minuto." : "Noticias apagadas."
      redirect_to(@comunidad.noticias_activas ? noticias_path : configuracion_noticias_path, notice: aviso)
    else
      render :configuracion, status: :unprocessable_entity
    end
  end

  def ocultar = cambiar_visibilidad(true)
  def mostrar = cambiar_visibilidad(false)

  private

  def comunidad = current_logia.organizacion

  def exigir_admin
    redirect_to(dashboard_path, alert: "Solo el administrador de la comunidad configura las noticias.") unless admin_de_la_comunidad?
  end

  def cambiar_visibilidad(oculta)
    comunidad.noticias.find(params[:id]).update!(oculta:)
    redirect_back_or_to noticias_path, notice: oculta ? "Noticia oculta para los miembros." : "Noticia visible otra vez."
  end
end
