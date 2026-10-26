# Reuniones del grupo (o de toda la comunidad): convocatoria con orden del día, confirmación, asistencia con
# quórum y acta. Quién ve y quién convoca está en AlcanceReuniones.
class ReunionesController < ApplicationController
  before_action -> { requiere_modulo!(:reuniones) }
  before_action :set_reunion, except: [:index, :new, :create, :desde_evento]
  before_action :exigir_gestion, only: [:edit, :update, :asistencia, :registrar_asistencia, :publicar_acta, :cancelar, :qr]

  def index
    visibles = Reunion.where(logia_id: logia_ids_de_reuniones).includes(:logia)
    # De una serie solo se lista la fecha más cercana; las demás se ven al abrirla.
    @proximas = visibles.proximas.to_a.uniq { _1.serie || "reunion-#{_1.id}" }
    @pasadas = visibles.pasadas.page(params[:page]).per(15)
  end

  def show
    @mi_respuesta = @reunion.respuesta_de(current_user)
    @confirmados = @reunion.confirmaciones.confirmados.count
    @rechazados = @reunion.confirmaciones.rechazados.count
    @mi_ficha = @reunion.convocados.find_by(id: current_miembro&.id)
  end

  def new
    return redirect_to reuniones_path, alert: "No convocas reuniones en esta comunidad." if logias_convocables.empty?
    inicio = Time.current.beginning_of_hour + 1.day
    @reunion = Reunion.new(logia_id: logias_convocables.first.id, inicio: inicio, fin: inicio + 2.hours)
  end

  def create
    @reunion = Reunion.new(reunion_params.merge(user: current_user))
    return head(:not_found) unless logias_convocables.map(&:id).include?(@reunion.logia_id)

    repetir = params[:repetir].presence_in(Reunion::REPETICIONES.keys)
    return render(:new, status: :unprocessable_entity) unless @reunion.valid?
    return convocar_serie(repetir, params[:veces].to_i.clamp(2, Reunion::MAX_FECHAS)) if repetir

    @reunion.save!
    NotificarReunionJob.perform_later(@reunion.id, "convocatoria")
    redirect_to reunion_path(@reunion), notice: "Convocatoria enviada: se avisó a los convocados."
  end

  # Un evento del calendario (con sus fechas siguientes, si es de una serie) pasa a ser reunión de un grupo que
  # la persona convoca. Lo hace quien gestiona el evento; lo de otra comunidad, o ya llevado, da 404.
  def desde_evento
    evento = CalendarioEvento.de_logias(logia_ids_de_la_organizacion).where.missing(:reunion).find(params[:evento_id])
    logia = logias_convocables.find { _1.id == params[:logia_id].to_i }
    return head(:not_found) unless logia && gestiona_evento?(evento)

    eventos = evento.esta_y_las_siguientes.where.missing(:reunion).to_a
    if eventos.size > Reunion::MAX_DESDE_EVENTOS
      return redirect_to calendario_path(evento), alert: "Son #{eventos.size} fechas; se llevan hasta #{Reunion::MAX_DESDE_EVENTOS}. Acorta la serie en el calendario."
    end

    reuniones = Reunion.desde_eventos!(eventos, logia: logia, user: current_user)
    aviso = reuniones.size > 1 ? "#{reuniones.size} fechas pasaron a ser #{logia.t_reunion.downcase}" : "Ahora es #{logia.t_reunion.downcase}"
    redirect_to reunion_path(reuniones.first), notice: "#{aviso}: orden del día, asistencia, acta y votaciones. Las respuestas se conservan."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to calendario_path(evento), alert: "No se pudo: #{e.record.errors.full_messages.to_sentence}."
  end

  def edit; end

  def update
    datos = reunion_params.except(:logia_id)
    if @reunion.update(datos)
      if @reunion.convocada? && (@reunion.saved_change_to_inicio? || @reunion.saved_change_to_lugar?)
        @reunion.update_column(:recordatorio_enviado_at, nil) if @reunion.saved_change_to_inicio?
        NotificarReunionJob.perform_later(@reunion.id, "cambio")
      end
      redirect_to reunion_path(@reunion), notice: "Cambios guardados."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # La respuesta queda en el evento del calendario: confirmar aquí o allí es lo mismo.
  def responder
    return head(:unprocessable_entity) unless params[:estado].in?(%w[confirmado rechazado])
    return redirect_to(reunion_path(@reunion), alert: "Ya no se admiten respuestas.") unless @reunion.convocada? && @reunion.calendario_evento

    conf = @reunion.calendario_evento.evento_confirmaciones.find_or_initialize_by(user: current_user)
    conf.update!(estado: params[:estado])
    redirect_to reunion_path(@reunion), notice: "Respuesta guardada."
  end

  def asistencia
    @convocados = @reunion.convocados.includes(:user).sort_by { _1.user.nombre_completo.to_s }
    @presentes = @reunion.reunion_asistencias.pluck(:miembro_id).to_set
    @confirmaron = @reunion.confirmaciones.confirmados.pluck(:user_id).to_set
  end

  # Solo cuentan los convocados: un id de otro grupo u otra comunidad se ignora.
  def registrar_asistencia
    ids = @reunion.convocados.where(id: Array(params[:miembro_ids]).map(&:to_i)).ids
    Reunion.transaction do
      @reunion.reunion_asistencias.where.not(miembro_id: ids).delete_all
      (ids - @reunion.reunion_asistencias.pluck(:miembro_id)).each { @reunion.reunion_asistencias.create!(miembro_id: _1) }
      @reunion.update!(estado: :celebrada) if @reunion.convocada?
    end
    redirect_to reunion_path(@reunion), notice: "Asistencia guardada: quórum del #{@reunion.quorum} %."
  end

  # El QR que se enseña en la reunión: cada convocado lo escanea y marca su asistencia desde su teléfono.
  def qr
    @reunion.regenerate_codigo_asistencia if @reunion.codigo_asistencia.blank?
    @url = presente_reunion_url(@reunion, codigo: @reunion.codigo_asistencia)
    @qr = RQRCode::QRCode.new(@url).as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true)
  end

  # Lo que abre el QR: confirmar con un botón (un GET no registra nada).
  def presente
    @mi_ficha = @reunion.convocados.find_by(id: current_miembro&.id)
    @codigo_valido = codigo_de_asistencia_valido?
    @ya_esta = @mi_ficha && @reunion.reunion_asistencias.exists?(miembro_id: @mi_ficha.id)
  end

  def marcar_presente
    ficha = @reunion.convocados.find_by(id: current_miembro&.id)
    unless ficha && codigo_de_asistencia_valido?
      return redirect_to reunion_path(@reunion), alert: "No se pudo registrar: el código no vale o la #{@reunion.logia.t_reunion.downcase} no está en curso."
    end

    @reunion.reunion_asistencias.find_or_create_by!(miembro_id: ficha.id)
    redirect_to reunion_path(@reunion), notice: "Quedó registrada tu asistencia."
  rescue ActiveRecord::RecordNotUnique
    redirect_to reunion_path(@reunion), notice: "Quedó registrada tu asistencia."
  end

  def publicar_acta
    return redirect_to(reunion_path(@reunion), alert: "Primero registra la asistencia.") unless @reunion.celebrada?
    return redirect_to(reunion_path(@reunion), alert: "El acta está vacía.") if @reunion.acta.blank?

    primera = !@reunion.acta_publicada?
    @reunion.update!(acta_publicada_at: Time.current)
    NotificarReunionJob.perform_later(@reunion.id, "acta") if primera
    redirect_to reunion_path(@reunion), notice: "Acta publicada."
  end

  def cancelar
    return redirect_to(reunion_path(@reunion), alert: "Solo se cancela lo que está convocado.") unless @reunion.convocada?

    if params[:alcance] == "siguientes" && @reunion.serie
      canceladas = @reunion.serie_desde_aqui.to_a
      Reunion.transaction { canceladas.each { _1.update!(estado: :cancelada) } }
      NotificarReunionJob.perform_later(@reunion.id, "serie_cancelada", canceladas.size)
      return redirect_to reunion_path(@reunion), notice: "Se cancelaron #{canceladas.size} fechas y se avisó a los convocados."
    end

    @reunion.update!(estado: :cancelada)
    NotificarReunionJob.perform_later(@reunion.id, "cancelada")
    redirect_to reunion_path(@reunion), notice: "Se canceló y se avisó a los convocados."
  end

  private

  # Crea todas las fechas de una vez y manda un solo aviso; cada fecha tendrá después su recordatorio.
  def convocar_serie(repetir, veces)
    serie = SecureRandom.uuid
    duracion = @reunion.fin - @reunion.inicio
    fechas = Reunion.fechas_de_serie(@reunion.inicio, repetir, veces)
    @reunion.serie = serie
    # Las copias se sacan antes de guardar la primera, que al guardarse recibe su evento del calendario.
    copias = fechas.drop(1).map { |inicio| @reunion.dup.tap { _1.assign_attributes(inicio: inicio, fin: inicio + duracion) } }
    Reunion.transaction { [@reunion, *copias].each(&:save!) }
    NotificarReunionJob.perform_later(@reunion.id, "serie", "#{veces} fechas, #{Reunion::REPETICIONES[repetir].downcase}")
    redirect_to reunion_path(@reunion), notice: "Se convocaron #{veces} fechas y se avisó a los convocados."
  end

  def set_reunion
    @reunion = Reunion.where(logia_id: logia_ids_de_reuniones).find(params[:id])
  end

  def codigo_de_asistencia_valido?
    @reunion.codigo_asistencia.present? && @reunion.asistencia_abierta? &&
      ActiveSupport::SecurityUtils.secure_compare(@reunion.codigo_asistencia, params[:codigo].to_s)
  end

  def exigir_gestion
    redirect_to reunion_path(@reunion), alert: "No gestionas esta convocatoria." unless gestiona_reunion?(@reunion)
  end

  def reunion_params
    params.require(:reunion).permit(:logia_id, :titulo, :inicio, :fin, :lugar, :orden_del_dia, :acta).tap do |p|
      p[:logia_id] = p[:logia_id].to_i if p.key?(:logia_id)
    end
  end
end
