module Denuncias
  # Enlace de acceso de las cuentas con alias. La URL se arma con el host FIJO de DENUNCIAPP, nunca
  # con el Host de la petición (un atacante podría pedir un enlace para la víctima hacia su dominio).
  class CuentasMailer < Devise::Passwordless::Mailer
    default from: -> { ENV["DENUNCIAS_CORREO_DE"].presence || "DENUNCIAPP <no-responder@#{Denuncias.host || 'localhost'}>" }
    default template_path: "denuncias/cuentas_mailer"

    def default_url_options
      u = URI(Denuncias.url.to_s)
      { host: u.host, protocol: u.scheme, port: u.port.in?([80, 443]) ? nil : u.port }
    end
  end
end
