class PerfilController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(perfil_params)
      redirect_to perfil_path, notice: "Perfil actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def perfil_params
    params.require(:user).permit(:nombre_visible)
  end
end
