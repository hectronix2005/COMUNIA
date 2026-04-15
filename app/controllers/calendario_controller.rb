class CalendarioController < ApplicationController
  helper_method :puede_gestionar_calendario?

  before_action :set_evento,      only: [:show, :edit, :update, :destroy]
  before_action :verificar_cargo, only: [:new, :create, :edit, :update, :destroy,
                                         :solicitar_sync, :responder_sync]

  # ── Index ─────────────────────────────────────────────────────
  def index
    @fecha  = parse_fecha
    @vista  = params[:vista].in?(%w[month week]) ? params[:vista] : "month"
    @filtro = params[:filtro].in?(%w[logia tenant]) ? params[:filtro] : "logia"

    if @vista == "week"
      @rango_inicio = @fecha.beginning_of_week(:monday)
      @rango_fin    = @fecha.end_of_week(:monday) + 1.day
      @dias_semana  = (@rango_inicio...@rango_fin).to_a
    else
      @mes_inicio   = @fecha.beginning_of_month
      @mes_fin      = @fecha.end_of_month
      @rango_inicio = @mes_inicio.beginning_of_week(:monday)
      @rango_fin    = @mes_fin.end_of_week(:monday) + 1.day
      @semanas      = (@rango_inicio...@rango_fin).to_a.each_slice(7).to_a
    end

    @eventos = CalendarioEvento
                 .de_logias(logia_ids_visibles)
                 .en_rango(@rango_inicio, @rango_fin)
                 .includes(:logia, :user)
                 .ordenados

    @eventos_por_dia = Hash.new { |h, k| h[k] = [] }
    @eventos.each do |e|
      fechas = e.todo_el_dia ? (e.inicio.to_date..e.fin.to_date).to_a : [e.inicio.to_date]
      fechas.each { |d| @eventos_por_dia[d] << e if d >= @rango_inicio && d < @rango_fin }
    end

    @logias_visibles = Logia.where(id: logia_ids_visibles)
    @sync_pendientes = CalendarioSincronizacion.para_logia(current_logia.id).pendientes.count
  end

  # ── CRUD ──────────────────────────────────────────────────────
  def show; end

  def new
    if params[:date].present?
      parsed    = Time.zone.parse(params[:date]) rescue nil
      # If it's a date-only string (no T), default to 8:00am
      inicio_dt = parsed || Time.current
      inicio_dt = inicio_dt.change(hour: 8) if params[:date].exclude?("T")
    else
      inicio_dt = Time.current.beginning_of_hour + 1.hour
    end

    @evento = CalendarioEvento.new(
      inicio: inicio_dt,
      fin:    inicio_dt + 1.hour,
      color:  current_logia.color_display,
      logia:  current_logia
    )
  end

  def create
    @evento = CalendarioEvento.new(evento_params)
    @evento.logia = current_logia
    @evento.user  = current_user

    if @evento.save
      redirect_to calendario_index_path(fecha: @evento.inicio.to_date, vista: params[:vista_retorno]),
                  notice: recurrence_notice(@evento)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @editar_serie = params[:serie] == "true" && @evento.instancia_de_serie?
  end

  def update
    editar_serie = params[:editar_serie] == "true"

    if editar_serie && @evento.instancia_de_serie?
      # Update the parent and regenerate all instances
      parent = @evento.serie
      if parent.update(evento_params_sin_recurrencia)
        parent.regenerar_instancias!
        redirect_to calendario_index_path(fecha: parent.inicio.to_date),
                    notice: "Serie completa actualizada."
      else
        @evento = parent
        render :edit, status: :unprocessable_entity
      end
    else
      if @evento.update(evento_params_sin_recurrencia)
        redirect_to calendario_index_path(fecha: @evento.inicio.to_date),
                    notice: "Evento actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    fecha = @evento.inicio.to_date

    case params[:eliminar]
    when "serie"
      if @evento.recurrente?
        @evento.instancias.delete_all
        @evento.destroy
      elsif @evento.instancia_de_serie?
        parent = @evento.serie
        parent.instancias.delete_all
        parent.destroy
      end
      redirect_to calendario_index_path(fecha: fecha), notice: "Serie completa eliminada."
    when "siguientes"
      if @evento.instancia_de_serie?
        @evento.serie.instancias.where("inicio >= ?", @evento.inicio).delete_all
      end
      @evento.destroy
      redirect_to calendario_index_path(fecha: fecha), notice: "Este evento y los siguientes fueron eliminados."
    else
      @evento.destroy
      redirect_to calendario_index_path(fecha: fecha), notice: "Evento eliminado."
    end
  end

  # ── Sincronizaciones ─────────────────────────────────────────
  def sincronizaciones
    @solicitudes     = CalendarioSincronizacion
                         .para_logia(current_logia.id)
                         .includes(:logia_solicitante, :logia_destino, :solicitado_por)
                         .order(created_at: :desc)
    @logias_sin_sync = logias_del_tenant_sin_sync
  end

  def solicitar_sync
    destino = Logia.find_by(id: params[:logia_destino_id])
    return redirect_to calendario_sincronizaciones_path, alert: "Logia no encontrada." unless destino

    sync = CalendarioSincronizacion.new(
      logia_solicitante: current_logia,
      logia_destino:     destino,
      solicitado_por:    current_user,
      estado:            "pendiente",
      mensaje:           params[:mensaje].to_s.strip.presence
    )

    if sync.save
      redirect_to calendario_sincronizaciones_path, notice: "Solicitud enviada a #{destino.nombre_display}."
    else
      redirect_to calendario_sincronizaciones_path, alert: sync.errors.full_messages.to_sentence
    end
  end

  def responder_sync
    sync = CalendarioSincronizacion.find(params[:id])
    return redirect_to calendario_sincronizaciones_path, alert: "Sin permiso." unless sync.logia_destino_id == current_logia.id

    sync.update!(estado: params[:accion] == "aceptar" ? "aceptada" : "rechazada")
    redirect_to calendario_sincronizaciones_path,
                notice: params[:accion] == "aceptar" ? "Sincronización aceptada." : "Solicitud rechazada."
  end

  private

  def set_evento
    @evento = CalendarioEvento.find(params[:id])
  end

  def verificar_cargo
    return if puede_gestionar_calendario?
    redirect_to calendario_index_path,
                alert: "Solo miembros con cargos oficiales o administradores pueden gestionar eventos."
  end

  def puede_gestionar_calendario?
    return true if current_user.rol_ref&.es_super_admin?
    return true if current_user.rol_ref&.codigo == "admin_logia"
    current_user.miembro&.miembro_cargos&.vigentes&.any?
  end

  def evento_params
    params.require(:calendario_evento).permit(
      :titulo, :descripcion, :inicio, :fin, :todo_el_dia, :color, :ubicacion,
      :recurrencia_tipo, :recurrencia_intervalo, :recurrencia_dias,
      :recurrencia_fin, :recurrencia_hasta, :recurrencia_count
    )
  end

  def evento_params_sin_recurrencia
    params.require(:calendario_evento).permit(
      :titulo, :descripcion, :inicio, :fin, :todo_el_dia, :color, :ubicacion
    )
  end

  def parse_fecha
    Date.parse(params[:fecha].to_s) rescue Date.current
  end

  def logia_ids_visibles
    @filtro == "tenant" ? logia_ids_del_tenant : [current_logia.id] + logias_sincronizadas_ids
  end

  def logia_ids_del_tenant
    ids = [current_logia.id]
    ids += current_logia.logias.pluck(:id) if current_logia.tenant_id.nil?
    ids
  end

  def logias_sincronizadas_ids
    CalendarioSincronizacion.aceptadas_para_logia(current_logia.id)
      .flat_map { |s| [s.logia_solicitante_id, s.logia_destino_id] }
      .uniq - [current_logia.id]
  end

  def logias_del_tenant_sin_sync
    todos   = logia_ids_del_tenant - [current_logia.id]
    ya_sync = CalendarioSincronizacion.para_logia(current_logia.id)
                .where.not(estado: "rechazada")
                .flat_map { |s| [s.logia_solicitante_id, s.logia_destino_id] }
                .uniq - [current_logia.id]
    Logia.where(id: todos - ya_sync)
  end

  def recurrence_notice(evento)
    if evento.recurrente?
      count = evento.instancias.count
      "Evento creado con #{count} repeticiones."
    else
      "Evento creado correctamente."
    end
  end
end
