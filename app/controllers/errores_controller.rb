# Errores registrados (ErrorApp), solo para el superadmin en el panel de plataforma.
class ErroresController < ApplicationController
  before_action do
    redirect_to root_path, alert: "Acceso exclusivo al administrador de plataforma." unless platform_admin_context?
  end

  def index
    @abiertos  = ErrorApp.abiertos.order(ultima_vez: :desc).limit(100)
    @resueltos = ErrorApp.resueltos.order(resuelto_at: :desc).limit(20)
  end

  def show
    @error = ErrorApp.find(params[:id])
  end

  def resolver
    ErrorApp.find(params[:id]).update!(resuelto_at: Time.current)
    redirect_to errores_path, notice: "Marcado como resuelto. Si vuelve a ocurrir, te llegará otro aviso."
  end
end
