# Pases anónimos de DENUNCIAPP (contrato v2, 19-oct-2026).
#   GET  /pases/claves.json  público: claves de la época actual y la anterior + sello_publico.
#   POST /pases/firmar       miembro activo: firma un mensaje cegado (máx. 4 por semana).
# Ni el mensaje cegado ni la firma se registran (filter_parameters) ni se guardan.
class PasesController < ApplicationController
  skip_before_action :authenticate_user!, only: :claves
  skip_after_action :track_last_seen
  wrap_parameters false

  rate_limit to: 60, within: 1.minute, only: :claves, with: -> { head :too_many_requests }
  rate_limit to: 10, within: 1.minute, only: :firmar, by: -> { current_user.id },
             with: -> { head :too_many_requests }

  def claves
    expires_in 5.minutes, public: true
    render json: { claves: Pases::Claves.publicadas.map(&:jwk), sello_publico: Pases.sello_publico? }
  end

  def firmar
    return head :forbidden unless current_miembro&.activo?

    clave = Pases::Claves.actual
    return head :service_unavailable unless clave
    # El navegador cegó con otra clave (cambio de mes): que vuelva a leer claves.json.
    return head :conflict unless params[:kid].to_s == clave.kid

    cegado = Pases.desde_b64(params[:cegado])
    return head :unprocessable_entity unless Pases::Firmante.valido?(clave, cegado)
    return head :too_many_requests unless PaseSemanal.reservar(current_miembro)

    response.headers["Cache-Control"] = "no-store"
    render json: { kid: clave.kid, firma_cegada: Pases.b64(Pases::Firmante.firmar(clave, cegado)) }
  rescue Pases::Firmante::Error
    head :unprocessable_entity
  end
end
