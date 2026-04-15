class BibliotecaLibrosController < ApplicationController
  before_action :set_libro,       only: [:show, :edit, :update, :destroy, :calificar]
  before_action :verificar_gestion, only: [:new, :create, :edit, :update, :destroy]

  def index
    @categoria_filtro = params[:categoria].in?(BibliotecaLibro::CATEGORIAS) ? params[:categoria] : nil
    scope = BibliotecaLibro
              .de_logia(current_logia.id)
              .activos
              .includes(:user, :calificaciones)
              .ordenados

    scope = scope.buscar(params[:q])          if params[:q].present?
    scope = scope.where(categoria: @categoria_filtro) if @categoria_filtro.present?

    @libros = scope
  end

  def show
    @calificacion     = @libro.calificacion_de(current_user)
    @nueva_calificacion = BibliotecaCalificacion.new
  end

  def new
    @libro = BibliotecaLibro.new(logia: current_logia)
  end

  def create
    @libro = BibliotecaLibro.new(libro_params)
    @libro.logia = current_logia
    @libro.user  = current_user

    if @libro.save
      redirect_to biblioteca_libros_path, notice: "Libro agregado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @libro.update(libro_params)
      redirect_to biblioteca_libro_path(@libro), notice: "Libro actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @libro.destroy
    redirect_to biblioteca_libros_path, notice: "Libro eliminado."
  end

  def calificar
    cal = @libro.calificacion_de(current_user)

    if cal
      cal.update(cal_params)
    else
      cal = @libro.calificaciones.build(cal_params.merge(user: current_user))
      cal.save
    end

    redirect_to biblioteca_libro_path(@libro), notice: "Calificación guardada."
  end

  private

  def set_libro
    @libro = BibliotecaLibro.find(params[:id])
  end

  def verificar_gestion
    return if puede_gestionar?
    redirect_to biblioteca_libros_path, alert: "Sin permiso para gestionar libros."
  end

  def puede_gestionar?
    return true if current_user.rol_ref&.es_super_admin?
    return true if current_user.rol_ref&.codigo == "admin_logia"
    current_user.miembro&.miembro_cargos&.vigentes&.any?
  end

  def libro_params
    params.require(:biblioteca_libro).permit(:titulo, :autor, :descripcion, :categoria, :anio, :url_externa, :activo, :archivo)
  end

  def cal_params
    params.require(:biblioteca_calificacion).permit(:puntuacion, :comentario)
  end
end
