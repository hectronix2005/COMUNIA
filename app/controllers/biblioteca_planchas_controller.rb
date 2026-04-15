class BibliotecaPlanchasController < ApplicationController
  before_action :set_plancha, only: [:show, :edit, :update, :destroy]
  before_action :verificar_gestion, only: [:new, :create, :edit, :update, :destroy]

  def index
    @grado_filtro = params[:grado].in?(BibliotecaPlancha::GRADOS) ? params[:grado] : nil
    @grado_usuario = current_user.miembro&.grado

    scope = BibliotecaPlancha
              .de_logia(current_logia.id)
              .activas
              .includes(:user)
              .ordenadas

    scope = scope.visibles_para(@grado_usuario) if @grado_usuario.present? && !puede_gestionar?
    scope = scope.de_grado(@grado_filtro)       if @grado_filtro.present?

    @planchas = scope
  end

  def show
    verificar_acceso_grado!
  end

  def new
    @plancha = BibliotecaPlancha.new(logia: current_logia)
  end

  def create
    @plancha = BibliotecaPlancha.new(plancha_params)
    @plancha.logia = current_logia
    @plancha.user  = current_user

    if @plancha.save
      redirect_to biblioteca_planchas_path, notice: "Plancha publicada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @plancha.update(plancha_params)
      redirect_to biblioteca_planchas_path, notice: "Plancha actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plancha.destroy
    redirect_to biblioteca_planchas_path, notice: "Plancha eliminada."
  end

  private

  def set_plancha
    @plancha = BibliotecaPlancha.find(params[:id])
  end

  def verificar_gestion
    return if puede_gestionar?
    redirect_to biblioteca_planchas_path, alert: "Sin permiso para gestionar planchas."
  end

  def verificar_acceso_grado!
    grado_usuario = current_user.miembro&.grado
    return if puede_gestionar?
    return unless grado_usuario.present?

    nivel_usuario = BibliotecaPlancha::GRADO_NIVEL[grado_usuario].to_i
    nivel_plancha = BibliotecaPlancha::GRADO_NIVEL[@plancha.grado].to_i

    if nivel_usuario < nivel_plancha
      redirect_to biblioteca_planchas_path, alert: "No tienes acceso a esta plancha."
    end
  end

  def puede_gestionar?
    return true if current_user.rol_ref&.es_super_admin?
    return true if current_user.rol_ref&.codigo == "admin_logia"
    current_user.miembro&.miembro_cargos&.vigentes&.any?
  end

  def plancha_params
    params.require(:biblioteca_plancha).permit(:titulo, :descripcion, :grado, :autor, :anio, :activo, :documento)
  end
end
