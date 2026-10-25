class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:edit, :update]

  def edit
    authorize @user
  end

  def update
    authorize @user
    if @user.update(user_params)
      redirect_to roles_path, notice: "Usuario actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # Mover a alguien de logia es cosa del superadmin (el selector solo se le muestra a él).
  def user_params
    permitidos = params.require(:user).permit(:nombre, :apellido, :email, :username, :logia_id)
    current_user.rol_ref&.es_super_admin? ? permitidos : permitidos.except(:logia_id)
  end
end
