# DENUNCIAPP dentro de COMUNIA (fusión decidida por Héctor el 19-oct-2026). Desde el 26-oct-2026 usa el
# login de COMUNIA: vive en /denuncias, el muro es público y denuncian los miembros activos con su sesión.
# La denuncia queda ligada al usuario (denuncias_reportes.user_id); en el muro no se muestra quién fue.
module Denuncias
  def self.table_name_prefix = "denuncias_"

  # Clave maestra AES-256-GCM (DENUNCIAS_CLAVE, 32 bytes en base64). Fuera de git y de las copias.
  def self.clave = Cripto.clave_maestra

  # Dónde se guardan los archivos de evidencia (originales cifrados y copias públicas).
  def self.dir_evidencia
    Pathname(ENV["DENUNCIAS_DIR"].presence || Rails.root.join("storage/denuncias#{'-test' if Rails.env.test?}"))
  end

  def self.contacto = ENV["DENUNCIAS_CONTACTO"].presence

  def self.turnstile_site_key = ENV["TURNSTILE_SITE_KEY"].presence
end
