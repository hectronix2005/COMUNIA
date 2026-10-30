# Guía: lo que cada uno puede hacer, según su rol y los módulos de su comunidad, con un enlace a cada sitio y el
# botón para repetir el recorrido guiado (recorrido_controller.js).
class GuiaController < ApplicationController
  def show
    return redirect_to(tenants_path) if platform_admin_context?
    redirect_to(dashboard_path) unless current_logia
  end
end
