class ReportePolicy < Struct.new(:user, :reporte)
  def cartera?
    user.tiene_permiso?("reportes", "cartera")
  end

  def recaudacion?
    user.tiene_permiso?("reportes", "recaudacion")
  end

  def morosos?
    user.tiene_permiso?("reportes", "morosos")
  end

  def recibo?
    user.tiene_permiso?("reportes", "recibo")
  end
end
