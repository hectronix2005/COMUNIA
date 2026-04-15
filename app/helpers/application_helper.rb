module ApplicationHelper
  def pesos(amount)
    number_to_currency(amount, unit: "$", delimiter: ".", separator: ",", precision: 0)
  end

  def estado_badge_class(estado)
    case estado.to_s
    when "pendiente" then "bg-warning text-dark"
    when "soporte_adjunto" then "bg-info"
    when "pagado" then "bg-success"
    when "vencido" then "bg-danger"
    when "activo" then "bg-success"
    when "inactivo" then "bg-secondary"
    when "suspendido" then "bg-danger"
    when "cerrado" then "bg-secondary"
    else "bg-secondary"
    end
  end

  def sort_link(titulo, columna)
    dir_actual = params[:orden] == columna ? params[:dir] : nil
    nueva_dir = dir_actual == "asc" ? "desc" : "asc"

    icono = if dir_actual == "asc"
              '<i class="bi bi-sort-up"></i>'
            elsif dir_actual == "desc"
              '<i class="bi bi-sort-down"></i>'
            else
              '<i class="bi bi-arrow-down-up text-muted"></i>'
            end

    link_to(
      "#{titulo} #{icono}".html_safe,
      url_for(request.query_parameters.merge(orden: columna, dir: nueva_dir)),
      class: "text-decoration-none text-white"
    )
  end

  def estado_label(estado)
    case estado.to_s
    when "pendiente" then "Pendiente"
    when "soporte_adjunto" then "Soporte Adjunto"
    when "pagado" then "Pagado"
    when "vencido" then "Vencido"
    when "activo" then "Activo"
    when "inactivo" then "Inactivo"
    when "suspendido" then "Suspendido"
    when "cerrado" then "Cerrado"
    else estado.to_s.humanize
    end
  end
end
