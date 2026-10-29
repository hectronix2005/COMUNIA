# Los administradores resuelven quién pidió entrar con el código de su logia: lo aprueban dándole una ficha
# que aún no tiene acceso (o una nueva) o lo rechazan. Aquí también se ve, se crea y se cambia el código.
class SolicitudesAccesoController < ApplicationController
  include FormularioPublico

  before_action :set_solicitud, only: [:show, :aprobar, :rechazar]

  def index
    authorize SolicitudAcceso
    base = de_la_organizacion(policy_scope(SolicitudAcceso)).includes(:logia)
    @pendientes = base.pendiente.order(:created_at)
    @resueltas = base.where.not(estado: :pendiente).includes(:decidida_por, miembro: :user).order(decidida_at: :desc).limit(20)
    @logias = logias_con_codigo
  end

  def show
    authorize @solicitud
    @fichas = @solicitud.pendiente? ? @solicitud.fichas_enlazables.select { policy(_1).invitar? } : []
  end

  def aprobar
    authorize @solicitud
    if params[:ficha] == "nueva"
      authorize @solicitud, :crear_ficha?
      @solicitud.aprobar_con_ficha_nueva!(cedula: texto(:cedula, 30), numero_miembro: texto(:numero_miembro, 30), por: current_user)
    else
      miembro = @solicitud.fichas_enlazables.find_by(id: texto(:miembro_id, 20))
      return redirect_to(solicitud_acceso_path(@solicitud), alert: "Elige la ficha que le corresponde.") unless miembro && policy(miembro).invitar?
      @solicitud.aprobar_con_ficha!(miembro, por: current_user)
    end
    redirect_to solicitudes_acceso_path, notice: "Aprobada: #{@solicitud.nombre_completo} ya puede entrar con su correo y su contraseña."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to solicitud_acceso_path(@solicitud), alert: e.record.errors.full_messages.to_sentence
  end

  def rechazar
    authorize @solicitud
    @solicitud.rechazar!(por: current_user, motivo: texto(:motivo, 300).presence)
    redirect_to solicitudes_acceso_path, notice: "Rechazada la solicitud de #{@solicitud.nombre_completo}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to solicitud_acceso_path(@solicitud), alert: e.record.errors.full_messages.to_sentence
  end

  # Crea el código o lo cambia: el anterior deja de servir, las solicitudes ya hechas siguen.
  def renovar_codigo
    logia = Logia.where(id: logias_con_codigo).find(params[:logia_id])
    authorize logia, :renovar_codigo?, policy_class: SolicitudAccesoPolicy
    logia.renovar_codigo_acceso!
    redirect_to solicitudes_acceso_path(anchor: "codigo-#{logia.id}"), notice: "Nuevo código de #{logia.nombre_display}: #{logia.codigo_acceso_legible}."
  end

  private

  def set_solicitud
    @solicitud = de_la_organizacion(policy_scope(SolicitudAcceso)).find(params[:id])
  end

  # Como en la lista de miembros: lo de otra organización no se ve aunque el rol alcance (superadmin).
  def de_la_organizacion(relacion)
    relacion.where(logia_id: logia_ids_de_la_organizacion)
  end

  def logias_con_codigo
    ids = current_user.logia_ids_accesibles
    logias = Logia.where(id: logia_ids_de_la_organizacion).ordenadas
    ids.nil? ? logias : logias.where(id: ids)
  end
end
