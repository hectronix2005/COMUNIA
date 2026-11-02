# Rastreo de lo que hace cada persona en las pruebas «family and friends» (Héctor, 1-nov-2026): visitas,
# páginas, tiempo en cada una, clics y errores. Se guarda en nuestra base (tablas ahoy_*), a todos los
# usuarios y sin borrado automático: se borra a mano cuando acaben las pruebas. Lo mira el superadmin en
# /rastreo. Nunca entran Denuncias ni la red (prometen anonimato), ni lo escrito en los formularios, ni
# los tokens que viajan en la URL (invitaciones, cambio de contraseña).
class Ahoy::Store < Ahoy::DatabaseStore
  # La página de entrada y la de origen, sin query string: ahí viaja el token de la invitación.
  def track_visit(data)
    data[:landing_page] = Ahoy::Store.sin_query(data[:landing_page])
    data[:referrer] = Ahoy::Store.sin_query(data[:referrer])
    super
  end

  def self.sin_query(url)
    url.to_s.split(/[?#]/, 2).first.presence
  end
end

Ahoy.api = true            # eventos desde el navegador (app/javascript/rastreo.js)
Ahoy.geocode = false
Ahoy.mask_ips = true       # guarda la IP sin el último número
Ahoy.visit_duration = 30.minutes

# Lo que no se rastrea: Denuncias y la red, y lo que piden máquinas (el calendario del teléfono, la PWA,
# los chequeos de salud), ni el propio panel /rastreo. Las peticiones de Ahoy mismo sí pasan.
Ahoy.exclude_method = lambda do |controller, request|
  ruta = controller&.controller_path.to_s
  next false if ruta.start_with?("ahoy/")
  ruta.start_with?("denuncias/", "red/") || ruta.in?(%w[suscripcion_calendario pwa salud rails/health rastreo]) ||
    request.path_info.match?(%r{\A/(denuncias|red)(/|\z)})
end
