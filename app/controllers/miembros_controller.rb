class MiembrosController < ApplicationController
  before_action :set_miembro, only: [:show, :edit, :update, :destroy, :cambiar_estado, :cambiar_rol]

  def index
    authorize Miembro
    base = policy_scope(Miembro)
    base = base.por_logia(params[:logia_id]) if params[:logia_id].present?

    @resumen_estados = base.group(:estado).count

    @miembros = base.includes(:user, :logia)

    @corte_fecha = params[:corte_fecha].present? ? (Date.parse(params[:corte_fecha].to_s) rescue nil) : nil

    estado_filtro = params.key?(:estado) ? params[:estado].presence : "activo"

    if @corte_fecha
      @miembros = @miembros.en_estado_en_fecha(estado_filtro || "activo", @corte_fecha)
    elsif estado_filtro.present?
      @miembros = @miembros.where(estado: estado_filtro)
    end

    if params[:buscar].present?
      term = "%#{params[:buscar]}%"
      @miembros = @miembros.joins(:user).where(
        "users.nombre ILIKE :t OR users.apellido ILIKE :t OR miembros.cedula ILIKE :t OR miembros.numero_miembro ILIKE :t",
        t: term
      )
    end

    @miembros = @miembros.page(params[:page])
    @logias = current_user.tiene_permiso?("logias", "index") ? Logia.ordenadas : Logia.where(id: current_user.logia_id)

    # Administradores del tenant actual (para el tab de admins)
    accesibles = current_user.logia_ids_accesibles
    logia_ids = if accesibles.nil?
      params[:logia_id].present? ? [ params[:logia_id].to_i ] : Logia.pluck(:id)
    elsif params[:logia_id].present?
      [ params[:logia_id].to_i ] & accesibles
    else
      accesibles
    end
    @admins = User.where(logia_id: logia_ids)
                  .joins(:rol_ref)
                  .where(roles: { codigo: "admin_logia" })
                  .includes(:logia)
                  .order(:apellido, :nombre)
  end

  def show
    authorize @miembro
  end

  def new
    @miembro = Miembro.new
    @miembro.build_user if @miembro.user.nil?
    authorize @miembro
    @logias = logias_disponibles
  end

  def create
    authorize Miembro

    logia_id = if current_user.scope_propia_logia?
                 current_user.logia_id
               else
                 miembro_params[:logia_id]
               end

    ActiveRecord::Base.transaction do
      user = User.new(
        nombre: params[:miembro][:user_attributes][:nombre],
        apellido: params[:miembro][:user_attributes][:apellido],
        email: params[:miembro][:user_attributes][:email],
        password: params[:miembro][:user_attributes][:password],
        rol: :miembro,
        rol_ref: Rol.find_by(codigo: "miembro"),
        logia_id: logia_id
      )

      @miembro = Miembro.new(
        numero_miembro: miembro_params[:numero_miembro],
        cedula: miembro_params[:cedula],
        grado: miembro_params[:grado],
        estado: :activo,
        logia_id: logia_id,
        user: user
      )

      if user.valid? && @miembro.valid?
        user.save!
        @miembro.save!
        redirect_to @miembro, notice: "Miembro creado exitosamente."
      else
        @miembro.errors.merge!(user.errors)
        @logias = logias_disponibles
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid
    @logias = logias_disponibles
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @miembro
    @logias = logias_disponibles
  end

  def update
    authorize @miembro
    attrs = miembro_update_params
    nuevo_estado = attrs[:estado]
    estado_previo = @miembro.estado

    ActiveRecord::Base.transaction do
      if nuevo_estado == "quite"
        attrs = attrs.merge(estado_hasta: nil)
      end
      @miembro.update!(attrs)

      # Cancelar cobros pendientes si transicionó a estado no-cobrable
      if nuevo_estado.present? && nuevo_estado != "activo" && estado_previo != nuevo_estado
        fecha_desde = @miembro.estado_desde
        fecha_hasta = nuevo_estado == "quite" ? nil : @miembro.estado_hasta
        cancelar_cobros_pendientes(@miembro, desde: fecha_desde, hasta: fecha_hasta)
      end

      # Registrar en historial si el estado cambió
      if nuevo_estado.present? && nuevo_estado != estado_previo
        registrar_cambio_estado(@miembro,
          estado:       nuevo_estado,
          desde:        @miembro.estado_desde || Date.current,
          hasta:        @miembro.estado_hasta,
          motivo:       @miembro.estado_motivo,
          soporte_file: params[:soporte_archivo]
        )
      end
    end

    redirect_to @miembro, notice: "Miembro actualizado exitosamente."
  rescue ActiveRecord::RecordInvalid
    @logias = logias_disponibles
    render :edit, status: :unprocessable_entity
  end

  def cambiar_estado
    authorize @miembro, :update?

    if request.patch?
      attrs = estado_params
      nuevo_estado = attrs[:estado]

      begin
        soporte_file = params[:soporte_archivo]

        # Validar soporte obligatorio para estados no-activos
        if nuevo_estado != "activo" && soporte_file.blank?
          @miembro.errors.add(:base, "Debe adjuntar el soporte documental (imagen o PDF)")
          render :cambiar_estado, status: :unprocessable_entity
          return
        end

        if nuevo_estado == "activo"
          ActiveRecord::Base.transaction do
            @miembro.update!(estado: :activo, estado_desde: nil, estado_hasta: nil, estado_motivo: nil)
            registrar_cambio_estado(@miembro, estado: "activo", desde: Date.current)
          end
          redirect_to @miembro, notice: "Miembro reactivado exitosamente."
        elsif nuevo_estado == "quite"
          cancelados = nil
          ActiveRecord::Base.transaction do
            @miembro.update!(attrs.merge(estado_hasta: nil))
            cancelados = cancelar_cobros_pendientes(@miembro)
            registrar_cambio_estado(@miembro,
              estado:        "quite",
              desde:         @miembro.estado_desde || Date.current,
              motivo:        @miembro.estado_motivo,
              soporte_file:  soporte_file
            )
          end
          redirect_to @miembro, notice: "Miembro marcado como Quite. Se eliminaron #{cancelados} cobro(s) pendiente(s)."
        else
          fecha_desde = attrs[:estado_desde].present? ? Date.parse(attrs[:estado_desde].to_s) : nil
          fecha_hasta = attrs[:estado_hasta].present? ? Date.parse(attrs[:estado_hasta].to_s) : nil
          cancelados = nil
          ActiveRecord::Base.transaction do
            @miembro.update!(attrs)
            cancelados = cancelar_cobros_pendientes(@miembro, desde: fecha_desde, hasta: fecha_hasta)
            registrar_cambio_estado(@miembro,
              estado:        nuevo_estado,
              desde:         fecha_desde || Date.current,
              hasta:         fecha_hasta,
              motivo:        attrs[:estado_motivo],
              soporte_file:  soporte_file
            )
          end
          redirect_to @miembro, notice: "Estado actualizado a #{@miembro.estado_label}. Se eliminaron #{cancelados} cobro(s) pendiente(s) del período."
        end
      rescue ActiveRecord::RecordInvalid
        render :cambiar_estado, status: :unprocessable_entity
      end
    end
  end

  def cambiar_rol
    authorize @miembro, :update?

    unless @miembro.activo?
      return redirect_to @miembro, alert: "Solo los miembros activos pueden tener el rol de Administrador."
    end

    nuevo_codigo = params[:rol_codigo].presence
    rol = Rol.find_by(codigo: nuevo_codigo) if nuevo_codigo
    unless rol && %w[admin_logia miembro].include?(rol.codigo)
      return redirect_to @miembro, alert: "Rol no válido."
    end

    @miembro.user.update!(rol_ref: rol)
    redirect_to @miembro, notice: "Rol actualizado a «#{rol.nombre}»."
  end

  def destroy
    authorize @miembro
    @miembro.user.destroy
    redirect_to miembros_path, notice: "Miembro eliminado exitosamente."
  end

  private

  def set_miembro
    @miembro = Miembro.find(params[:id])
  end

  def miembro_params
    params.require(:miembro).permit(:numero_miembro, :cedula, :grado, :logia_id,
      user_attributes: [:nombre, :apellido, :email, :password])
  end

  def miembro_update_params
    params.require(:miembro).permit(:numero_miembro, :cedula, :grado, :fecha_ingreso, :estado, :estado_desde, :estado_hasta, :estado_motivo)
  end

  # Elimina cobros en estado pendiente del miembro dentro del rango inactivo.
  # Sin rango = elimina todos los pendientes.
  def cancelar_cobros_pendientes(miembro, desde: nil, hasta: nil)
    cobros = miembro.cobros.pendiente.joins(:periodo_cobro)
    if desde
      cobros = cobros.where("make_date(periodo_cobros.anio, periodo_cobros.mes, 1) >= ?", desde.beginning_of_month)
    end
    if hasta
      cobros = cobros.where("make_date(periodo_cobros.anio, periodo_cobros.mes, 1) <= ?", hasta.end_of_month)
    end
    count = cobros.count
    cobros.destroy_all
    count
  end

  def estado_params
    params.require(:miembro).permit(:estado, :estado_desde, :estado_hasta, :estado_motivo)
  end

  def logias_disponibles
    current_user.tiene_permiso?("logias", "index") ? Logia.ordenadas : Logia.where(id: current_user.logia_id)
  end

  def registrar_cambio_estado(miembro, estado:, desde:, hasta: nil, motivo: nil, soporte_file: nil)
    cambio = miembro.estado_cambios.build(
      estado:         estado,
      desde:          desde,
      hasta:          hasta,
      motivo:         motivo,
      registrado_por: current_user
    )
    cambio.soporte.attach(soporte_file) if soporte_file.present?
    cambio.save!
    cambio
  end
end
