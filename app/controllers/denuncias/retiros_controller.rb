module Denuncias
  # Solicitud de retiro de una publicación (Ley 1581). La puede pedir cualquiera, con o sin cuenta:
  # sin sesión, con captcha. Con UMBRAL_OCULTAR solicitudes pendientes, la publicación se oculta sola.
  class RetirosController < BaseController
    before_action :buscar_reporte

    def new; end

    def create
      llave = user_signed_in? ? "u#{current_user.id}" : request.remote_ip.to_s
      unless limite?(:retiro, llave)
        return volver("Demasiadas solicitudes; espera una hora.", :too_many_requests)
      end
      return volver("Completa la verificación de seguridad.") unless user_signed_in? || Captcha.valido?(params["cf-turnstile-response"])

      motivo = texto(params[:motivo], 10, 2000)
      contacto = params[:contacto].presence && texto(params[:contacto], 3, 200)
      return volver("Explica el motivo (mínimo 10 caracteres).") if motivo.nil? || (params[:contacto].present? && contacto.nil?)
      # Una misma persona no cuenta dos veces para ocultar la publicación.
      unless limite?(:retiro_reporte, "#{llave}|#{@reporte.id}")
        return redirect_to(denuncias_muro_path, notice: "Ya habías pedido retirar esa publicación; el operador la revisará.")
      end

      Retiro.solicitar(@reporte, motivo: motivo, contacto: contacto)
      redirect_to denuncias_muro_path, notice: "Solicitud enviada. El operador la revisará."
    end

    private

    def buscar_reporte
      @reporte = Reporte.find_by(id: params[:id].to_s, estado: "publicado")
      no_encontrado unless @reporte
    end

    def volver(error, estado = :unprocessable_content)
      @error = error
      render :new, status: estado
    end
  end
end
