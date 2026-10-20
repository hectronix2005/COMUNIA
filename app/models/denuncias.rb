# DENUNCIAPP dentro de COMUNIA (fusión decidida por Héctor el 19-oct-2026).
# El módulo vive en OTRO host (DENUNCIAPP_URL) que apunta a esta misma app: allí solo
# existen sus rutas, la cookie de sesión de COMUNIA no viaja (es solo de su host) y no se
# registra nada que identifique a quien denuncia. Ninguna tabla denuncias_* enlaza con
# users, miembros ni logias. Traspaso y riesgos: ~/referencias/DENUNCIAPP/docs/traspaso-a-comunia.md
module Denuncias
  def self.table_name_prefix = "denuncias_"

  # Host del módulo, sacado de DENUNCIAPP_URL. Sin él, el módulo no existe.
  def self.url
    url = ENV["DENUNCIAPP_URL"].to_s.strip.chomp("/")
    url if url.start_with?("https://") || (Rails.env.local? && url.start_with?("http://"))
  end

  def self.host = url && URI(url).host

  def self.host?(request_o_host)
    h = request_o_host.respond_to?(:host) ? request_o_host.host : request_o_host.to_s.split(":").first
    host.present? && h.to_s.casecmp?(host)
  end

  # Clave maestra AES-256-GCM (DENUNCIAS_CLAVE, 32 bytes en base64). Fuera de git y de las copias.
  def self.clave = Cripto.clave_maestra

  # Dónde se guardan los archivos de evidencia (originales cifrados y copias públicas).
  def self.dir_evidencia
    Pathname(ENV["DENUNCIAS_DIR"].presence || Rails.root.join("storage/denuncias#{'-test' if Rails.env.test?}"))
  end

  def self.contacto = ENV["DENUNCIAS_CONTACTO"].presence

  def self.turnstile_site_key = ENV["TURNSTILE_SITE_KEY"].presence

  # Cuentas con alias: solo si hay correo de verdad configurado (o en desarrollo, con el enlace en el log).
  def self.cuentas? = ENV["DENUNCIAS_CUENTAS"] == "1" || Rails.env.local?
end
