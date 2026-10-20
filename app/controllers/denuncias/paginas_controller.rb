module Denuncias
  # Páginas del muro (el frontal de DENUNCIAPP, casi intacto) y sus archivos estáticos.
  class PaginasController < BaseController
    ESTATICOS = {
      "estilo.css" => "text/css", "comun.js" => "text/javascript", "pase.js" => "text/javascript",
      "muro.js" => "text/javascript", "nuevo.js" => "text/javascript", "cuenta.js" => "text/javascript",
      "entrar.js" => "text/javascript", "terminos.js" => "text/javascript"
    }.freeze
    CARPETA = Rails.root.join("app/denuncias_web")

    # Rails rechaza (422) un GET que devuelve JavaScript sin ser XHR, para que otra web no lo
    # incruste con <script>. Estos archivos son públicos y no dependen de la sesión.
    skip_forgery_protection only: :estatico

    def muro = render(:muro)
    def nuevo = render(:nuevo)
    def cuenta = render(:cuenta)
    def entrar = render(:entrar)
    def terminos = render(:terminos)

    def estatico
      # El nombre sale de la lista, nunca del parámetro.
      nombre = ESTATICOS.keys.find { |n| n == params[:archivo] } or return head(:not_found)
      expires_in 5.minutes, public: true
      send_file CARPETA.join(nombre), type: ESTATICOS.fetch(nombre), disposition: :inline
    end
  end
end
