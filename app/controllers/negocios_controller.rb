class NegociosController < ApplicationController
  before_action :set_anuncio, only: [:show, :edit, :update, :destroy, :toggle_favorito, :remove_imagen]
  before_action :verificar_propietario, only: [:edit, :update, :destroy, :remove_imagen]

  ORDEN_OPCIONES = {
    "recientes"   => { column: :created_at,   direction: :desc },
    "antiguos"    => { column: :created_at,   direction: :asc },
    "precio_asc"  => { column: :precio,       direction: :asc  },
    "precio_desc" => { column: :precio,       direction: :desc },
    "populares"   => { column: :vistas_count, direction: :desc }
  }.freeze

  def index
    @tipo_filtro = params[:tipo].in?(NegocioAnuncio::TIPOS) ? params[:tipo] : nil
    @orden       = ORDEN_OPCIONES.key?(params[:orden]) ? params[:orden] : "recientes"
    logia_ids    = logia_ids_visibles

    scope = NegocioAnuncio
              .where(logia_id: logia_ids)
              .activos
              .includes(:user, :logia)

    scope = scope.de_tipo(@tipo_filtro)             if @tipo_filtro.present?
    scope = scope.buscar(params[:q])                if params[:q].present?
    scope = scope.where("precio >= ?", params[:precio_min]) if params[:precio_min].present?
    scope = scope.where("precio <= ?", params[:precio_max]) if params[:precio_max].present?
    scope = scope.where("ubicacion ILIKE ?", "%#{params[:ubicacion]}%") if params[:ubicacion].present?
    scope = scope.where(categoria: params[:categoria]) if params[:categoria].present?
    scope = scope.where(estado: params[:estado]) if params[:estado].present? && NegocioAnuncio::ESTADOS.include?(params[:estado])

    if params[:solo_favoritos] == "1" && current_user
      fav_ids = current_user.negocio_favoritos.pluck(:negocio_anuncio_id)
      scope = scope.where(id: fav_ids)
    end

    orden_cfg = ORDEN_OPCIONES[@orden]
    scope = scope.order(orden_cfg[:column] => orden_cfg[:direction])

    @total_resultados = scope.count
    @anuncios = scope.page(params[:page]).per(12)
  end

  def show
    # Increment atómico en una sola query (antes eran update_all + reload).
    @anuncio.increment!(:vistas_count)
  end

  def new
    @anuncio = NegocioAnuncio.new(logia: current_logia, tipo: params[:tipo] || "servicio")
  end

  def create
    @anuncio = NegocioAnuncio.new(anuncio_params)
    @anuncio.logia = current_logia
    @anuncio.user  = current_user

    if @anuncio.save
      redirect_to negocio_path(@anuncio), notice: "Anuncio publicado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @anuncio.update(anuncio_params)
      redirect_to negocio_path(@anuncio), notice: "Anuncio actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @anuncio.destroy
    redirect_to negocios_path, notice: "Anuncio eliminado."
  end

  def toggle_favorito
    fav = NegocioFavorito.find_or_initialize_by(user: current_user, negocio_anuncio: @anuncio)
    if fav.persisted?
      fav.destroy
      @fav_state = false
    else
      fav.save
      @fav_state = true
    end
    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.replace("fav_#{@anuncio.id}", partial: "negocios/fav_btn", locals: { anuncio: @anuncio })]
        streams << turbo_stream.replace("fav_inline_#{@anuncio.id}", partial: "negocios/fav_btn_inline", locals: { anuncio: @anuncio })
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: negocio_path(@anuncio) }
    end
  end

  def remove_imagen
    blob = ActiveStorage::Blob.find_signed(params[:blob_id])
    if blob && @anuncio.imagenes.attachments.where(blob_id: blob.id).destroy_all.any?
      redirect_to edit_negocio_path(@anuncio), notice: "Imagen eliminada."
    else
      redirect_to edit_negocio_path(@anuncio), alert: "No se pudo eliminar la imagen."
    end
  end

  private

  def set_anuncio
    @anuncio = NegocioAnuncio.find_by_slug_or_id(params[:id])
  end

  def verificar_propietario
    return if current_user.rol_ref&.es_super_admin?
    return if current_user.rol_ref&.codigo == "admin_logia"
    return if @anuncio.user_id == current_user.id
    redirect_to negocios_path, alert: "Sin permiso."
  end

  def logia_ids_visibles
    ids = [current_logia.id]
    if current_logia.tenant_id.nil?
      ids += current_logia.logias.pluck(:id)
    else
      ids += [current_logia.tenant_id]
      root = Logia.find(current_logia.tenant_id)
      ids  += root.logias.pluck(:id)
    end
    ids.uniq
  end

  def anuncio_params
    params.require(:negocio_anuncio).permit(
      :titulo, :descripcion, :tipo, :categoria, :precio, :moneda,
      :contacto, :ubicacion, :activo, :imagen, :estado,
      :latitud, :longitud,
      imagenes: []
    )
  end
end
