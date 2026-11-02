# Las sombrillas de la cuenta (su barrio, su localidad, su ciudad): muro, eventos y noticias. Solo entra quien es
# de una comunidad anclada debajo (o el superadmin); para las demás es un 404, como lo que no existe. El
# superadmin lleva aquí el catálogo: crea barrios y ancla comunidades de categoría Barrio.
class SombrillasController < ApplicationController
  before_action :cargar_sombrilla, only: %i[show eventos noticias publicar crear_evento]
  before_action :exigir_superadmin, only: %i[crear anclar]

  def index
    @mias = Sombrilla.de_usuario(current_user).to_a
    return unless superadmin?

    @ciudades = Sombrilla.where(nivel: "ciudad").ordenadas
    @localidades = Sombrilla.where(nivel: "localidad").includes(:padre).ordenadas
    @barrios = Sombrilla.barrios.includes(:padre, :comunidades).ordenadas
    @anclables = Logia.tenants_raiz.reales.joins(:categoria).where(categorias: { nombre: Sombrilla::CATEGORIA_ANCLABLE })
                      .includes(:sombrilla).ordenadas
  end

  def show
    @publicaciones = visibles(@sombrilla.publicaciones).recientes
                     .includes(:user, :comunidad, imagenes_attachments: :blob, comentarios: %i[user comunidad])
                     .page(params[:page]).per(15)
  end

  def eventos
    @eventos = visibles(@sombrilla.eventos).proximos.includes(:user, :comunidad)
  end

  def noticias
    @noticias = visibles(@sombrilla.noticias).recientes.page(params[:page]).per(20)
  end

  def publicar
    return unless puede_publicar?

    publicacion = @sombrilla.publicaciones.new(params.require(:sombrilla_publicacion).permit(:contenido, imagenes: []))
    publicacion.assign_attributes(user: current_user, comunidad: @comunidad)
    if publicacion.save
      redirect_to sombrilla_path(@sombrilla), notice: "Publicado en #{@sombrilla.nombre}."
    else
      redirect_to sombrilla_path(@sombrilla), alert: publicacion.errors.full_messages.to_sentence
    end
  end

  def crear_evento
    return unless puede_publicar?(eventos_sombrilla_path(@sombrilla))

    evento = @sombrilla.eventos.new(params.require(:sombrilla_evento).permit(:titulo, :inicio, :lugar, :descripcion))
    evento.assign_attributes(user: current_user, comunidad: @comunidad)
    if evento.save
      redirect_to eventos_sombrilla_path(@sombrilla), notice: "Evento publicado en #{@sombrilla.nombre}."
    else
      redirect_to eventos_sombrilla_path(@sombrilla), alert: evento.errors.full_messages.to_sentence
    end
  end

  # Cómo aparece la cuenta en todas sus sombrillas.
  def visibilidad
    valor = params[:visibilidad].to_s
    if User::VISIBILIDADES_SOMBRILLA.key?(valor)
      current_user.update_column(:visibilidad_sombrilla, valor)
      redirect_back fallback_location: sombrillas_path, notice: "Listo: así apareces en tu barrio, tu localidad y tu ciudad."
    else
      redirect_back fallback_location: sombrillas_path, alert: "Elige una de las opciones."
    end
  end

  # Superadmin: un barrio nuevo dentro de una localidad.
  def crear
    barrio = Sombrilla.new(nombre: params[:nombre], nivel: "barrio", padre: Sombrilla.find_by(id: params[:padre_id], nivel: "localidad"))
    if barrio.save
      redirect_to sombrillas_path, notice: "Barrio #{barrio.nombre} creado en #{barrio.padre.nombre}."
    else
      redirect_to sombrillas_path, alert: barrio.errors.full_messages.to_sentence
    end
  end

  # Superadmin: ancla (o desancla, sin barrio) una comunidad de categoría Barrio.
  def anclar
    comunidad = Logia.tenants_raiz.find(params[:logia_id])
    barrio = Sombrilla.barrios.find_by(id: params[:sombrilla_id])
    if comunidad.update(sombrilla: barrio)
      redirect_to sombrillas_path, notice: barrio ? "#{comunidad.nombre} quedó en #{barrio.nombre}." : "#{comunidad.nombre} quedó sin barrio."
    else
      redirect_to sombrillas_path, alert: comunidad.errors.full_messages.to_sentence
    end
  end

  private

  def superadmin? = current_user.rol_ref&.es_super_admin?
  helper_method :superadmin?

  def exigir_superadmin
    head :not_found unless superadmin?
  end

  def cargar_sombrilla
    @sombrilla = Sombrilla.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @sombrilla.accesible_para?(current_user)

    @modera = @sombrilla.modera?(current_user)
    @comunidad = @sombrilla.comunidad_de(current_user)
    @cadena = superadmin? && @comunidad.nil? ? @sombrilla.cadena : Sombrilla.de_usuario(current_user).to_a
  end

  # Lo oculto solo lo ven los moderadores.
  def visibles(relacion) = @modera ? relacion : relacion.visibles

  # Publica quien es de una comunidad de aquí y ya eligió cómo aparece.
  def puede_publicar?(volver = sombrilla_path(@sombrilla))
    if @comunidad.nil?
      redirect_to volver, alert: "Publica quien es de una comunidad de #{@sombrilla.nombre}."
    elsif current_user.visibilidad_sombrilla.nil?
      redirect_to volver, alert: "Antes de publicar, elige cómo quieres aparecer."
    else
      return true
    end
    false
  end
end
