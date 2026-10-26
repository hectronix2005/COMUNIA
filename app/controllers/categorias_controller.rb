# Categorías de comunidad (Masonería, Club, Barrio, Universidad…), solo para el superadmin en el panel de
# plataforma. Cada una fija cómo se llaman las cosas y qué módulos ven sus comunidades.
class CategoriasController < ApplicationController
  before_action do
    redirect_to root_path, alert: "Acceso exclusivo al administrador de plataforma." unless platform_admin_context?
  end
  before_action :set_categoria, only: [:edit, :update, :destroy]

  def index
    @categorias = Categoria.ordenadas
    @comunidades = Logia.tenants_raiz.where.not(categoria_id: nil).order(:nombre).group_by(&:categoria_id)
    @sin_categoria = Logia.tenants_raiz.where(categoria_id: nil).order(:nombre)
  end

  def new
    @categoria = Categoria.new(modulos: Categoria::MODULOS.keys - ["grados"])
  end

  def create
    @categoria = Categoria.new(categoria_params)
    if @categoria.save
      redirect_to categorias_path, notice: "Categoría «#{@categoria.nombre}» creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @categoria.update(categoria_params)
      redirect_to categorias_path, notice: "Categoría «#{@categoria.nombre}» actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @categoria.destroy
      redirect_to categorias_path, notice: "Categoría «#{@categoria.nombre}» eliminada."
    else
      redirect_to categorias_path, alert: "No se puede eliminar: tiene comunidades. Cámbialas de categoría primero."
    end
  end

  private

  def set_categoria
    @categoria = Categoria.find(params[:id])
  end

  def categoria_params
    params.require(:categoria).permit(:nombre, :icono, *Categoria::TERMINOS.map { :"termino_#{_1}" }, modulos: [])
  end
end
