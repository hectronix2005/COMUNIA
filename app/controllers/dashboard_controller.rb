class DashboardController < ApplicationController
  def index
    if current_user.rol_ref&.es_super_admin?
      if platform_admin_context?
        # Sin subdominio y sin preview → panel de plataforma COMUNIA
        return redirect_to tenants_path
      elsif previewing_tenant?
        # En preview → dashboard del tenant activo (como admin de esa logia)
        dashboard_admin_logia_para(current_logia)
      else
        # Subdominio activo → dashboard del tenant del subdominio
        dashboard_admin_logia_para(current_logia)
      end
    elsif current_user.tiene_permiso?("miembros", "index") && current_user.scope_propia_logia?
      dashboard_admin_logia
    else
      dashboard_miembro
    end
  end

  private

  def dashboard_super_admin
    @logias = Logia.ordenadas
    @total_miembros = Miembro.activos.count
    @total_cobros_pendientes = Cobro.pendiente.count
    @total_soporte_adjunto = Cobro.soporte_adjunto.count
    @total_pagados = Cobro.pagado.count
    @total_vencidos = Cobro.vencido.count
    @cobros_recientes = Cobro.soporte_adjunto.includes(miembro: [:user, :logia]).order(updated_at: :desc).limit(10)

    @resumen_por_logia = Logia.ordenadas.map do |logia|
      cobros = Cobro.por_logia(logia.id)
      {
        logia: logia,
        pendientes: cobros.pendiente.count,
        soporte_adjunto: cobros.soporte_adjunto.count,
        pagados: cobros.pagado.count,
        vencidos: cobros.vencido.count
      }
    end

    render "dashboard/super_admin"
  end

  def dashboard_admin_logia
    dashboard_admin_logia_para(current_user.logia)
  end

  def dashboard_admin_logia_para(logia)
    @logia = logia
    @miembros_activos = Miembro.activos.por_logia(logia.id).count
    cobros = Cobro.por_logia(logia.id)
    @pendientes      = cobros.pendiente.count
    @soporte_adjunto = cobros.soporte_adjunto.count
    @pagados         = cobros.pagado.count
    @vencidos        = cobros.vencido.count
    @cobros_por_validar = cobros.soporte_adjunto.includes(miembro: :user).order(updated_at: :desc).limit(10)

    # Tesorería: montos
    @monto_cartera  = cobros.pendiente.sum(:monto)
    @monto_mora     = cobros.vencido.sum(:monto)
    @monto_mes      = Pago.validados
                         .joins(cobro: :miembro)
                         .where(miembros: { logia_id: logia.id })
                         .where(validado_at: Date.current.beginning_of_month..Date.current.end_of_month)
                         .sum(:monto_pagado)
    @monto_anio     = Pago.validados
                         .joins(cobro: :miembro)
                         .where(miembros: { logia_id: logia.id })
                         .where(validado_at: Date.current.beginning_of_year..Date.current.end_of_year)
                         .sum(:monto_pagado)

    # Módulos nuevos
    cargar_datos_modulos(logia)

    render "dashboard/admin_logia"
  end

  def dashboard_miembro
    if current_miembro
      @cobros = current_miembro.cobros.includes(:periodo_cobro, :pago).order(created_at: :desc)
      @pendientes = @cobros.select(&:pendiente?)
      @soporte_adjunto = @cobros.select(&:soporte_adjunto?)
      @pagados = @cobros.select(&:pagado?)
      @vencidos = @cobros.select(&:vencido?)
    else
      @cobros = []
      @pendientes = @soporte_adjunto = @pagados = @vencidos = []
    end

    cargar_datos_modulos(current_logia) if current_logia

    render "dashboard/miembro"
  end

  def cargar_datos_modulos(logia)
    hoy = Date.current
    ids = ids_tenant(logia)

    @biblioteca_planchas_count = BibliotecaPlancha.where(logia_id: ids).activas.count
    @biblioteca_libros_count   = BibliotecaLibro.where(logia_id: ids).activos.count

    recaudado = HospitaliaRecaudo.where(logia_id: ids).sum(:monto)
    gastado   = HospitaliaGasto.where(logia_id: ids).sum(:monto)
    @hospitalia_saldo = recaudado - gastado
    @hospitalia_cumpleanos = MiembroFamiliar
                               .joins(miembro: :logia)
                               .where(logias: { id: ids })
                               .con_cumpleanos
                               .to_a
                               .select { |f|
                                 cumple = f.fecha_nacimiento.change(year: hoy.year)
                                 cumple = cumple.change(year: hoy.year + 1) if cumple < hoy
                                 (cumple - hoy).to_i <= 30
                               }.count

    @negocios_count = NegocioAnuncio.where(logia_id: ids).activos.count
  rescue => e
    Rails.logger.warn "dashboard cargar_datos_modulos: #{e.message}"
  end

  def ids_tenant(logia)
    ids = [logia.id]
    if logia.tenant_id.nil?
      ids += logia.logias.pluck(:id)
    else
      ids << logia.tenant_id
      root = Logia.find_by(id: logia.tenant_id)
      ids += root.logias.pluck(:id) if root
    end
    ids.uniq
  end
end
