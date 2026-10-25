# Red social de comunidades certificadas (piloto del 24-oct-2026, encargo de Héctor).
#
# Cada persona publica lo que necesita u ofrece y la avalan comunidades certificadas: un club, una
# universidad, un barrio, una empresa… La confianza crece con el número y el tamaño de esas
# comunidades.
#
# Regla innegociable: una comunidad NUNCA sabe a qué otras pertenece una persona.
# - Las comunidades de alguien solo están en red_membresias. Desde fuera solo se ven ella misma y la
#   plataforma (el superadmin).
# - Lo que ven los demás es la Ficha (Red::Ficha). Sale de la foto diaria de red_confianzas: nivel,
#   número de comunidades y una banda del total de miembros. Nunca nombres ni ids.
# - Lo oculto responde igual que lo que no existe, y el orden de los resultados solo usa datos
#   públicos.
# Las pruebas que intentan sacar esa información están en test/red/privacidad_test.rb.
module Red
  def self.table_name_prefix = "red_"

  # Versión de la política de tratamiento de datos (Ley 1581) que acepta cada persona.
  POLITICA_VERSION = "2026-10-24".freeze

  NIVELES = { 0 => "Sin certificar", 1 => "Básico", 2 => "Confiable", 3 => "Alto", 4 => "Muy alto" }.freeze

  # Bandas de tamaño: hacia fuera nunca se da una cifra exacta de miembros.
  BANDAS = {
    "ninguno" => "ninguna comunidad",
    "menos_de_100" => "menos de 100 miembros",
    "100_a_1000" => "entre 100 y 1.000 miembros",
    "1000_a_10000" => "entre 1.000 y 10.000 miembros",
    "mas_de_10000" => "más de 10.000 miembros"
  }.freeze

  def self.banda(n)
    if n <= 0 then "ninguno"
    elsif n < 100 then "menos_de_100"
    elsif n < 1_000 then "100_a_1000"
    elsif n < 10_000 then "1000_a_10000"
    else "mas_de_10000"
    end
  end

  # Moderadores y certificadores de la plataforma. Por ahora, el superadmin de COMUNIA.
  def self.moderador?(user) = user&.rol_ref&.es_super_admin? || false

  def self.moderadores = User.joins(:rol_ref).where(roles: { codigo: "super_admin" })

  # Aviso dentro de COMUNIA (y push). Nunca rompe la acción que lo dispara.
  def self.avisar(user, titulo, cuerpo = nil, url = nil, tipo: "red_aviso")
    NotificacionService.crear!(user: user, tipo: tipo, titulo: titulo, cuerpo: cuerpo, url: url)
  rescue StandardError => e
    Rails.logger.warn("[red] aviso no enviado: #{e.class}")
    nil
  end

  # Ids de las comunidades certificadas en las que `user` está verificado y vigente. Es la única
  # puerta para saber «qué ve esta persona»; nunca se usa para enseñar nada de otra.
  def self.comunidades_de(user)
    return [] unless user
    Membresia.vigentes.where(user_id: user.id).pluck(:comunidad_id)
  end
end
