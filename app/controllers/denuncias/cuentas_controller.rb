module Denuncias
  # Cuentas con alias (enlace mágico de devise-passwordless). Pedir el enlace es un formulario
  # público: límite de intentos y captcha antes de crear o tocar ninguna cuenta. Las rutas que usan
  # la cookie exigen que Origin sea el propio sitio.
  class CuentasController < BaseController
    before_action :cuentas_habilitadas

    def estado
      c = cuenta_actual
      render json: c ? { sesion: true, alias: c.alias } : { sesion: false }
    end

    def pedir_enlace
      return unless limite!(:entrar)
      return redirect_to("/entrar?error=captcha") unless Captcha.valido?(params["cf-turnstile-response"])
      cuenta = Cuenta.buscar_o_crear(params[:email].is_a?(String) ? params[:email] : "")
      cuenta&.send_magic_link
      # Misma respuesta exista o no la cuenta (no revela correos registrados).
      redirect_to "/entrar?enviado=1"
    end

    def elegir_alias
      c = cuenta_actual
      return render(json: { error: "Inicia sesión" }, status: :unauthorized) unless c && mismo_origen?
      case c.asignar_alias(params[:alias])
      when :ok then render json: { alias: c.alias }
      when :ocupado then render json: { error: "Ese alias no está disponible" }, status: :conflict
      else render json: { error: "El alias lleva de 3 a 20 letras minúsculas, números o _" }, status: :bad_request
      end
    end

    def mis_reportes
      c = cuenta_actual
      return render(json: { error: "Inicia sesión" }, status: :unauthorized) unless c
      render json: c.reportes.order(n: :desc).map { |r|
        { id: r.id, categoria: r.categoria, estado: r.estado, titulo: r.titulo, localidad: r.localidad,
          fecha: Cripto.fecha_bogota(r.creado_en), verificada: r.verificada && r.sello_publico }
      }
    end

    def retirar
      c = cuenta_actual
      return render(json: { error: "Inicia sesión" }, status: :unauthorized) unless c && mismo_origen?
      r = c.reportes.find_by(id: params[:id].to_s)
      return render(json: { error: "No encontrado" }, status: :not_found) if r.nil? || r.estado == "retirado"
      Retiro.retirar(r, "retirado_por_autor")
      render json: { id: r.id, estado: "retirado" }
    end

    def salir
      sign_out(:cuenta)
      redirect_to "/"
    end

    private

    def cuentas_habilitadas
      head :not_found unless Denuncias.cuentas?
    end
  end
end
