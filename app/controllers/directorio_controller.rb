class DirectorioController < ApplicationController
  def index
    @miembros = Miembro.where(logia_id: logia_ids_visibles)
                       .activos.includes(:user, :logia, :cargos)
                       .order("users.apellido, users.nombre")
                       .joins(:user)

    if params[:q].present?
      q = "%#{Miembro.sanitize_sql_like(params[:q])}%"
      @miembros = @miembros.where(
        "users.nombre ILIKE :q OR users.apellido ILIKE :q OR miembros.profesion ILIKE :q OR miembros.empresa ILIKE :q",
        q: q
      )
    end

    if params[:logia_id].present?
      @miembros = @miembros.where(logia_id: params[:logia_id])
    end

    @miembros = @miembros.page(params[:page]).per(24)
    @logias = Logia.where(id: logia_ids_visibles).order(:nombre)
  end

  def show
    @miembro = Miembro.where(logia_id: logia_ids_visibles).includes(:user, :logia, :cargos, :miembro_cargos).find(params[:id])
  end

  def edit
    @miembro = current_user.miembro
    redirect_to directorio_index_path, alert: "No tienes un perfil de miembro." unless @miembro
  end

  def update
    @miembro = current_user.miembro
    if @miembro.update(directorio_params)
      if params[:miembro][:avatar].present?
        @miembro.user.avatar.attach(params[:miembro][:avatar])
      end
      redirect_to directorio_path(@miembro), notice: "Perfil actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def directorio_params
    params.require(:miembro).permit(:profesion, :empresa, :telefono, :habilidades, :fecha_iniciacion, :bio)
  end
end
