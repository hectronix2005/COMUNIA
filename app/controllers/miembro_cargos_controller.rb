class MiembroCargosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_miembro

  def create
    # Seed cargos predefinidos si la logia aún no los tiene
    Cargo.seed_para_logia(@miembro.logia) if Cargo.where(logia_id: @miembro.logia_id).none?

    @miembro_cargo = @miembro.miembro_cargos.build(cargo_params)
    @miembro_cargo.asignado_por = current_user

    if @miembro_cargo.save
      redirect_to miembro_path(@miembro), notice: "Cargo asignado correctamente."
    else
      redirect_to miembro_path(@miembro), alert: @miembro_cargo.errors.full_messages.to_sentence
    end
  end

  def update
    @miembro_cargo = @miembro.miembro_cargos.find(params[:id])
    if @miembro_cargo.update(hasta: params[:miembro_cargo][:hasta] || Date.current)
      redirect_to miembro_path(@miembro), notice: "Cargo finalizado."
    else
      redirect_to miembro_path(@miembro), alert: @miembro_cargo.errors.full_messages.to_sentence
    end
  end

  def destroy
    @miembro.miembro_cargos.find(params[:id]).destroy
    redirect_to miembro_path(@miembro), notice: "Cargo eliminado."
  end

  private

  def set_miembro
    @miembro = Miembro.find(params[:miembro_id])
    authorize @miembro, :update?
  end

  def cargo_params
    params.require(:miembro_cargo).permit(:cargo_id, :desde, :hasta, :nuevo_cargo_nombre)
      .tap do |p|
        if p[:cargo_id].blank? && p[:nuevo_cargo_nombre].present?
          cargo = Cargo.find_or_create_by(nombre: p[:nuevo_cargo_nombre].strip, logia_id: @miembro.logia_id)
          p[:cargo_id] = cargo.id
        end
        p.delete(:nuevo_cargo_nombre)
      end
  end
end
