class LogiasController < ApplicationController
  before_action :set_logia, only: [:show, :edit, :update]

  def show
    authorize @logia
    @estado_filtro = params.key?(:estado) ? params[:estado].presence : "activo"
    base = @logia.miembros.includes(:user)
    if @estado_filtro == "irregular"
      base = base.where(estado: %w[irregular_temporal irregular_permanente])
    elsif @estado_filtro.present?
      base = base.where(estado: @estado_filtro)
    end

    @sort_col = %w[numero_miembro cedula grado nombre].include?(params[:sort]) ? params[:sort] : "numero_miembro"
    @sort_dir = params[:dir] == "desc" ? "desc" : "asc"

    base = case @sort_col
           when "nombre"
             base.joins(:user).order("users.apellido #{@sort_dir}, users.nombre #{@sort_dir}")
           else
             base.order("miembros.#{@sort_col} #{@sort_dir}")
           end

    @miembros = base.page(params[:page])
  end

  def edit
    authorize @logia
  end

  def update
    authorize @logia
    if @logia.update(logia_params)
      redirect_to @logia, notice: "#{@logia.t_logia} actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_logia
    @logia = Logia.find(params[:id])
  end

  def logia_params
    params.require(:logia).permit(:nombre, :codigo, :slug,
                                  :nombre_app, :icono, :lema, :color_primario,
                                  :termino_miembro, :termino_logia, :termino_cobro,
                                  :logo)
  end
end
