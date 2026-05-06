class HospitaliaController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_action :require_hospitalario!, except: %i[cumpleanos enviar_felicitacion familiares create_familiar destroy_familiar]

  def index
    @recaudos = HospitaliaRecaudo.de_logia(current_logia.id).ordenados.limit(10)
    @gastos   = HospitaliaGasto.de_logia(current_logia.id).ordenados.limit(10)
    @total_recaudado = HospitaliaRecaudo.de_logia(current_logia.id).sum(:monto)
    @total_gastado   = HospitaliaGasto.de_logia(current_logia.id).sum(:monto)
    @saldo           = @total_recaudado - @total_gastado
    @recaudo         = HospitaliaRecaudo.new(fecha: Date.current)
    @gasto           = HospitaliaGasto.new(fecha: Date.current)
    @miembros        = Miembro.por_logia(current_logia.id).activos.includes(:user).order("users.nombre")
  end

  # ── Recaudos ──────────────────────────────────────────────────
  def recaudos
    @recaudos = HospitaliaRecaudo.de_logia(current_logia.id).includes(:user, :miembro).ordenados
    @recaudo  = HospitaliaRecaudo.new(fecha: Date.current)
    @miembros = Miembro.por_logia(current_logia.id).activos.includes(:user).order("users.nombre")
  end

  def create_recaudo
    @recaudo = HospitaliaRecaudo.new(recaudo_params)
    @recaudo.logia = current_logia
    @recaudo.user  = current_user

    if @recaudo.save
      redirect_to hospitalia_recaudos_path, notice: "Recaudo registrado: #{number_to_currency(@recaudo.monto, unit: '$', delimiter: '.', separator: ',')}."
    else
      @recaudos = HospitaliaRecaudo.de_logia(current_logia.id).includes(:user, :miembro).ordenados
      @miembros = Miembro.por_logia(current_logia.id).activos.includes(:user).order("users.nombre")
      render :recaudos, status: :unprocessable_entity
    end
  end

  def destroy_recaudo
    @recaudo = HospitaliaRecaudo.find(params[:id])
    @recaudo.destroy
    redirect_to hospitalia_recaudos_path, notice: "Recaudo eliminado."
  end

  # ── Gastos ────────────────────────────────────────────────────
  def gastos
    @gastos  = HospitaliaGasto.de_logia(current_logia.id).includes(:user, :beneficiario).ordenados
    @gasto   = HospitaliaGasto.new(fecha: Date.current)
    @miembros = Miembro.por_logia(current_logia.id).activos.includes(:user).order("users.nombre")
  end

  def create_gasto
    @gasto = HospitaliaGasto.new(gasto_params)
    @gasto.logia = current_logia
    @gasto.user  = current_user

    if @gasto.save
      redirect_to hospitalia_gastos_path, notice: "Gasto registrado: #{number_to_currency(@gasto.monto, unit: '$', delimiter: '.', separator: ',')}."
    else
      @gastos  = HospitaliaGasto.de_logia(current_logia.id).includes(:user, :beneficiario).ordenados
      @miembros = Miembro.por_logia(current_logia.id).activos.includes(:user).order("users.nombre")
      render :gastos, status: :unprocessable_entity
    end
  end

  def destroy_gasto
    @gasto = HospitaliaGasto.find(params[:id])
    @gasto.destroy
    redirect_to hospitalia_gastos_path, notice: "Gasto eliminado."
  end

  # ── Cumpleaños ────────────────────────────────────────────────
  def cumpleanos
    hoy     = Date.current
    @miembros_logia = Miembro.where(logia_id: logia_ids_visibles).activos.includes(:user, :familiares)

    # Lista completa de cumpleaños (todo el año), ordenada por proximidad
    @proximos = []

    @miembros_logia.each do |m|
      m.familiares.con_cumpleanos.each do |f|
        begin
          cumple = f.fecha_nacimiento.change(year: hoy.year)
        rescue Date::Error
          next
        end
        cumple = cumple.change(year: hoy.year + 1) if cumple < hoy
        dias   = (cumple - hoy).to_i
        @proximos << { nombre: f.nombre_completo, tipo: "Familiar",
                       parentesco: f.parentesco, miembro: m,
                       fecha: cumple, dias: dias }
      end
    end

    @proximos.sort_by! { |p| p[:dias] }

    # Permite filtrar por rango de días con ?rango=30|90|365 (default: todos)
    @rango = params[:rango].to_i
    @proximos = @proximos.select { |p| p[:dias] <= @rango } if @rango.positive?
  end

  def enviar_felicitacion
    miembro = Miembro.find(params[:miembro_id])
    texto   = params[:texto].presence || "Querido H∴ #{miembro.user.nombre_completo}, en nombre de la Logia te enviamos nuestros más sinceros deseos en este día tan especial. ¡Feliz cumpleaños!"

    ChatMensaje.create!(
      logia:         current_logia,
      user:          current_user,
      destinatario:  miembro.user,
      canal:         "dm",
      contenido:     texto
    )

    redirect_to hospitalia_cumpleanos_path, notice: "Felicitación enviada a #{miembro.user.nombre_completo}."
  end

  # ── Familiares ────────────────────────────────────────────────
  def familiares
    @miembro  = Miembro.find(params[:miembro_id])
    @familiares = @miembro.familiares.order(:nombre_completo)
    @familiar   = MiembroFamiliar.new
  end

  def create_familiar
    @miembro = Miembro.find(params[:miembro_id])
    @familiar = @miembro.familiares.build(familiar_params)

    if @familiar.save
      redirect_to hospitalia_familiares_path(miembro_id: @miembro.id), notice: "Familiar agregado."
    else
      @familiares = @miembro.familiares.order(:nombre_completo)
      render :familiares, status: :unprocessable_entity
    end
  end

  def destroy_familiar
    @familiar = MiembroFamiliar.find(params[:id])
    miembro_id = @familiar.miembro_id
    @familiar.destroy
    redirect_to hospitalia_familiares_path(miembro_id: miembro_id), notice: "Familiar eliminado."
  end

  private


  def logia_ids_visibles
    ids = [current_logia.id]
    if current_logia.tenant_id.nil?
      ids += current_logia.logias.pluck(:id)
    else
      ids += [current_logia.tenant_id]
      root = Logia.find_by(id: current_logia.tenant_id)
      ids += root.logias.pluck(:id) if root
    end
    ids.uniq
  end

  def recaudo_params
    params.require(:hospitalia_recaudo).permit(:concepto, :monto, :fecha, :descripcion, :miembro_id, :soporte)
  end

  def gasto_params
    params.require(:hospitalia_gasto).permit(:concepto, :monto, :fecha, :descripcion, :beneficiario_id, :soporte)
  end

  def familiar_params
    params.require(:miembro_familiar).permit(:nombre_completo, :parentesco, :fecha_nacimiento)
  end
end
