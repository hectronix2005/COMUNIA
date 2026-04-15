class CobrosController < ApplicationController
  before_action :require_tesorero!
  before_action :set_cobro, only: [:show, :adjuntar_soporte, :subir_soporte, :validar, :confirmar_pago, :rechazar_pago]

  def index
    @cobros = policy_scope(Cobro)
                .includes(:periodo_cobro, :pago, miembro: [:user, :logia])
                .joins(:periodo_cobro, miembro: [:user, :logia])
                .left_joins(:pago)
    @cobros = @cobros.por_estado(params[:estado]) if params[:estado].present?
    @cobros = @cobros.por_logia(params[:logia_id]) if params[:logia_id].present?
    @cobros = @cobros.where(periodo_cobro_id: params[:periodo_id]) if params[:periodo_id].present?
    if params[:miembro_ids].present?
      @cobros = @cobros.where(miembro_id: Array(params[:miembro_ids]).compact_blank)
    elsif params[:miembro_id].present?
      @cobros = @cobros.where(miembro_id: params[:miembro_id])
    end

    @cobros = @cobros.order(orden_sql).page(params[:page])

    @logias = current_user.tiene_permiso?("logias", "index") ? Logia.ordenadas : []
    logia_scope = current_user.scope_propia_logia? ? current_user.logia_id : nil
    @periodos = PeriodoCobro.recientes
    @miembros = Miembro.includes(:user)
                       .then { |q| logia_scope ? q.where(logia_id: logia_scope) : q }
                       .order("users.apellido ASC, users.nombre ASC")
                       .references(:user)
  end

  def show
    authorize @cobro
  end

  # Formulario para subir soporte de varios cobros a la vez (miembro o admin)
  def adjuntar_soporte_multiple
    authorize Cobro

    cobro_ids = Array(params[:cobro_ids]).map(&:to_i)

    if current_user.tiene_permiso?("cobros", "validar")
      # Admin: puede adjuntar soporte para cualquier miembro
      @cobros = policy_scope(Cobro)
                  .where(id: cobro_ids, estado: [:pendiente, :vencido])
                  .includes(:periodo_cobro, miembro: [:user, :logia])
                  .order("periodo_cobros.anio ASC, periodo_cobros.mes ASC")
    elsif current_user.miembro
      @cobros = current_user.miembro.cobros
                  .where(id: cobro_ids, estado: [:pendiente, :vencido])
                  .includes(:periodo_cobro, miembro: [:user, :logia])
                  .order("periodo_cobros.anio ASC, periodo_cobros.mes ASC")
    else
      redirect_to cobros_path, alert: "No tienes permiso para esta acción."
      return
    end

    if @cobros.empty?
      redirect_to cobros_path, alert: "Selecciona al menos un cobro pendiente."
      return
    end

    @cobros_por_miembro = @cobros.group_by(&:miembro)
    @total = @cobros.sum(:monto)
    @descuento = Pago.calcular_descuento(@cobros.count, @total)
    @pago = Pago.new(
      monto_pagado: @descuento[:total_con_descuento],
      fecha_pago: Date.current,
      metodo_pago: "transferencia"
    )
  end

  # Procesa la subida del soporte para varios cobros (miembro o admin)
  def subir_soporte_multiple
    authorize Cobro

    cobro_ids = Array(params[:cobro_ids]).map(&:to_i)

    if current_user.tiene_permiso?("cobros", "validar")
      @cobros = policy_scope(Cobro)
                  .where(id: cobro_ids, estado: [:pendiente, :vencido])
                  .includes(:periodo_cobro, miembro: [:user, :logia])
                  .order("periodo_cobros.anio ASC, periodo_cobros.mes ASC")
    elsif current_user.miembro
      @cobros = current_user.miembro.cobros
                  .where(id: cobro_ids, estado: [:pendiente, :vencido])
                  .includes(:periodo_cobro, miembro: [:user, :logia])
                  .order("periodo_cobros.anio ASC, periodo_cobros.mes ASC")
    else
      redirect_to cobros_path, alert: "No tienes permiso para esta acción."
      return
    end

    if @cobros.empty?
      redirect_to cobros_path, alert: "No se encontraron cobros validos."
      return
    end

    @cobros_por_miembro = @cobros.group_by(&:miembro)
    @total = @cobros.sum(:monto)
    @descuento = Pago.calcular_descuento(@cobros.count, @total)
    soporte_files = Array(params.dig(:pago, :soportes)).compact_blank
    pago_attrs = params.require(:pago).permit(:monto_pagado, :fecha_pago, :metodo_pago, :observaciones)

    # Validar que venga al menos un archivo
    if soporte_files.empty?
      @pago = Pago.new(pago_attrs.merge(monto_pagado: @total))
      @pago.cobro = @cobros.first
      @pago.valid? # trigger other validations
      @pago.errors.add(:soportes, "debe adjuntar al menos un comprobante")
      render :adjuntar_soporte_multiple, status: :unprocessable_entity
      return
    end

    # Validar formato/tamano de cada archivo antes de guardar
    soporte_files.each do |soporte_file|
      unless soporte_file.content_type.in?(%w[image/jpeg image/png application/pdf])
        @pago = Pago.new(pago_attrs.merge(monto_pagado: @total, cobro: @cobros.first))
        @pago.errors.add(:soportes, "debe ser JPG, PNG o PDF")
        render :adjuntar_soporte_multiple, status: :unprocessable_entity
        return
      end

      if soporte_file.size > 5.megabytes
        @pago = Pago.new(pago_attrs.merge(monto_pagado: @total, cobro: @cobros.first))
        @pago.errors.add(:soportes, "no debe superar 5MB por archivo")
        render :adjuntar_soporte_multiple, status: :unprocessable_entity
        return
      end
    end

    # Validar otros campos del pago (sin attach, para no consumir el tempfile)
    @pago = Pago.new(pago_attrs.merge(monto_pagado: @total, cobro: @cobros.first))
    @pago.errors.clear
    @pago.errors.add(:monto_pagado, "no puede estar en blanco") if pago_attrs[:monto_pagado].blank?
    @pago.errors.add(:fecha_pago, "no puede estar en blanco") if pago_attrs[:fecha_pago].blank?
    @pago.errors.add(:metodo_pago, "no puede estar en blanco") if pago_attrs[:metodo_pago].blank?
    if @pago.errors.any?
      render :adjuntar_soporte_multiple, status: :unprocessable_entity
      return
    end

    # Subir blobs una sola vez y reutilizar en cada pago
    blobs = soporte_files.map do |sf|
      ActiveStorage::Blob.create_and_upload!(
        io: sf.tempfile,
        filename: sf.original_filename,
        content_type: sf.content_type
      )
    end

    es_tesoreria = current_user.tiene_permiso?("cobros", "validar")

    ActiveRecord::Base.transaction do
      @cobros.each do |cobro|
        pago = cobro.pago || cobro.build_pago

        # Calcular monto individual con descuento prorrateado
        if @descuento[:aplica]
          proporcion = cobro.monto.to_f / @total.to_f
          descuento_individual = (@descuento[:descuento] * proporcion).round(0)
          pago.monto_pagado = cobro.monto - descuento_individual
          pago.descuento_porcentaje = @descuento[:porcentaje]
          pago.descuento_monto = descuento_individual
        else
          pago.monto_pagado = cobro.monto
        end

        pago.fecha_pago = pago_attrs[:fecha_pago]
        pago.metodo_pago = pago_attrs[:metodo_pago]
        pago.observaciones = pago_attrs[:observaciones]
        blobs.each { |blob| pago.soportes.attach(blob) }
        pago.save!

        if es_tesoreria
          pago.update!(validado_por: current_user, validado_at: Time.current)
          cobro.pagado!
        else
          cobro.soporte_adjunto!
        end
      end
    end

    miembros_count = @cobros.map(&:miembro_id).uniq.size
    msg = "Soporte adjuntado para #{@cobros.count} cobro(s)"
    msg += " de #{miembros_count} miembro(s)" if miembros_count > 1
    if es_tesoreria
      msg += ". Pagos validados — RC Pendiente."
    else
      msg += ". Pendiente de validacion."
    end
    redirect_to cobros_path, notice: msg
  rescue ActiveRecord::RecordInvalid => e
    @cobros_por_miembro ||= @cobros&.includes(miembro: [:user, :logia])&.group_by(&:miembro) || {}
    @pago ||= Pago.new
    @pago.errors.add(:base, e.message)
    render :adjuntar_soporte_multiple, status: :unprocessable_entity
  end

  def parsear_soporte
    authorize Cobro, :parsear_soporte?

    # Modo 1: archivo subido directamente (desde formulario de adjuntar)
    if params[:archivo].present?
      resultado = SoporteParser.new(params[:archivo]).call
      render json: resultado
      return
    end

    # Modo 2: cobro_id para analizar soporte ya guardado
    if params[:cobro_id].present?
      cobro = Cobro.find(params[:cobro_id])
      pago = cobro.pago
      if pago.nil? || !pago.soportes.attached?
        render json: { error: "No hay soporte adjunto para este cobro" }, status: :bad_request
        return
      end

      force = ActiveModel::Type::Boolean.new.cast(params[:force])

      # Obtener datos OCR (cacheados o nuevos) - analizar el primer soporte
      if pago.datos_ocr.present? && !force
        datos_ocr = pago.datos_ocr
      else
        datos_ocr = nil
        primer_soporte = pago.soportes.first
        primer_soporte.open do |tempfile|
          archivo = ActionDispatch::Http::UploadedFile.new(
            tempfile: tempfile,
            filename: primer_soporte.filename.to_s,
            type: primer_soporte.content_type
          )
          datos_ocr = SoporteParser.new(archivo).call
          pago.update_column(:datos_ocr, datos_ocr)
        end
      end

      # Validar contra el cobro/miembro real
      resultado = SoporteValidador.new(datos_ocr, cobro).call
      render json: resultado
      return
    end

    render json: { error: "No se recibio archivo ni cobro_id" }, status: :bad_request
  rescue => e
    Rails.logger.error("SoporteParser error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Miembro: formulario para subir soporte
  def adjuntar_soporte
    authorize @cobro
    @pago = @cobro.pago || @cobro.build_pago(
      monto_pagado: @cobro.monto,
      fecha_pago: Date.current,
      metodo_pago: "transferencia"
    )
  end

  # Miembro o Admin: procesa la subida del soporte
  def subir_soporte
    authorize @cobro
    @pago = @cobro.pago || @cobro.build_pago

    @pago.assign_attributes(pago_params)
    @pago.monto_pagado ||= @cobro.monto
    @pago.fecha_pago ||= Date.current

    if @pago.save
      if current_user.tiene_permiso?("cobros", "validar")
        # Tesorería: auto-validar → pagado con RC Pendiente
        @pago.update!(validado_por: current_user, validado_at: Time.current)
        @cobro.pagado!
        redirect_to cobro_path(@cobro), notice: "Pago validado — RC Pendiente."
      else
        @cobro.soporte_adjunto!
        redirect_to cobro_path(@cobro), notice: "Soporte adjuntado exitosamente. Pendiente de validación."
      end
    else
      render :adjuntar_soporte, status: :unprocessable_entity
    end
  end

  # Admin: vista para validar el pago
  def validar
    authorize @cobro
    @pago = @cobro.pago

    if @pago.nil?
      redirect_to cobro_path(@cobro), alert: "Este cobro no tiene soporte de pago adjunto."
      return
    end

    @cobros_grupo = @pago.cobros_grupo
    @total_grupo = @cobros_grupo.sum(:monto)
  end

  # Admin: confirma el pago y genera RC (todos los cobros del grupo)
  def confirmar_pago
    authorize @cobro
    pago = @cobro.pago

    if pago.nil?
      redirect_to cobro_path(@cobro), alert: "No hay soporte de pago adjunto."
      return
    end

    cobros_grupo = pago.cobros_grupo.where(estado: :soporte_adjunto)
    rcs = []

    ActiveRecord::Base.transaction do
      cobros_grupo.each do |cobro|
        rc = cobro.pago.validar!(current_user)
        rcs << rc
      end
    end

    if rcs.size > 1
      redirect_to cobros_path, notice: "#{rcs.size} pagos validados. RC pendiente de asignacion."
    else
      redirect_to cobro_path(@cobro), notice: "Pago validado. RC pendiente de asignacion."
    end
  end

  # Admin: rechaza el pago (todos los cobros del grupo)
  def rechazar_pago
    authorize @cobro
    pago = @cobro.pago

    if pago.nil?
      redirect_to cobro_path(@cobro), alert: "No hay soporte de pago."
      return
    end

    cobros_grupo = pago.cobros_grupo.where(estado: :soporte_adjunto)

    ActiveRecord::Base.transaction do
      cobros_grupo.each do |cobro|
        cobro.pago.rechazar!
      end
    end

    redirect_to cobros_path, notice: "#{cobros_grupo.size > 1 ? "#{cobros_grupo.size} pagos rechazados" : "Pago rechazado"}. Los cobros vuelven a estado pendiente."
  end

  private

  def set_cobro
    @cobro = Cobro.find(params[:id])
  end

  def pago_params
    params.require(:pago).permit(:monto_pagado, :fecha_pago, :metodo_pago, :observaciones, soportes: [])
  end

  COLUMNAS_ORDEN = {
    "periodo"  => "periodo_cobros.anio %{dir}, periodo_cobros.mes %{dir}",
    "miembro"  => "users.apellido %{dir}, users.nombre %{dir}",
    "logia"    => "logias.nombre %{dir}",
    "monto"    => "cobros.monto %{dir}",
    "estado"   => "cobros.estado %{dir}",
    "rc"       => "pagos.numero_rc %{dir} NULLS LAST"
  }.freeze

  def orden_sql
    col = COLUMNAS_ORDEN[params[:orden]]
    dir = params[:dir] == "asc" ? "ASC" : "DESC"
    if col
      Arel.sql(col % { dir: dir })
    else
      Arel.sql("periodo_cobros.anio DESC, periodo_cobros.mes DESC, users.apellido ASC")
    end
  end
end
