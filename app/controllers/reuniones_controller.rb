# Reuniones del grupo (o de toda la comunidad): convocatoria con orden del día, confirmación, asistencia con
# quórum y acta. Quién ve y quién convoca está en AlcanceReuniones.
class ReunionesController < ApplicationController
  before_action -> { requiere_modulo!(:reuniones) }
  before_action :set_reunion, except: [:index, :new, :create]
  before_action :exigir_gestion, only: [:edit, :update, :asistencia, :registrar_asistencia, :publicar_acta, :cancelar]

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

  def exigir_gestion
    redirect_to reunion_path(@reunion), alert: "No gestionas esta convocatoria." unless gestiona_reunion?(@reunion)
  end

  def reunion_params
    params.require(:reunion).permit(:logia_id, :titulo, :inicio, :fin, :lugar, :orden_del_dia, :acta).tap do |p|
      p[:logia_id] = p[:logia_id].to_i if p.key?(:logia_id)
    end
  end
end
