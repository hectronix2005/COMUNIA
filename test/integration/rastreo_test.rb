require "test_helper"

# Rastreo de las pruebas «family and friends» (config/initializers/ahoy.rb): cada petición deja su evento, el
# navegador manda vistas y errores, y el superadmin lo lee en /rastreo. Denuncias y la red quedan fuera.
class RastreoTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  NAVEGADOR = { "User-Agent" => "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " \
                                "(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36" }.freeze

  setup do
    preparar_denuncias
    @yo = vecino("Nelson")
    @logia = @yo.logia
  end

  teardown { limpiar_denuncias }

  test "cada petición deja un evento con la ruta sin query string, su acción y su estado" do
    sign_in @yo
    get "/t/#{@logia.slug}/dashboard?invitation_token=SECRETO", headers: NAVEGADOR
    assert_response :ok

    visita = Ahoy::Visit.sole
    assert_equal @yo.id, visita.user_id
    assert_equal "Chrome Mobile", visita.browser
    evento = Ahoy::Event.find_by!(name: "Petición")
    assert_equal "/t/#{@logia.slug}/dashboard", evento.properties["ruta"]
    assert_equal "dashboard#index", evento.properties["accion"]
    assert_equal 200, evento.properties["estado"]
    assert_kind_of Integer, evento.properties["ms"]
    assert_not_includes Ahoy::Visit.pluck(:landing_page, :referrer).flatten.join + Ahoy::Event.pluck(:properties).to_json, "SECRETO"
  end

  test "también queda lo que cortan los filtros: entrar sin sesión lleva al login" do
    get "/dashboard", headers: NAVEGADOR
    evento = Ahoy::Event.find_by!(name: "Petición")
    assert_response :redirect
    assert_equal 401, evento.properties["estado"]
    assert_equal "login", evento.properties["destino"]
  end

  test "un error dentro de la acción se anota con su clase y estado 500" do
    sign_in @yo
    DashboardController.class_eval { def fallar_rastreo = raise("fallo de prueba") }
    DashboardController.before_action :fallar_rastreo, only: :index
    assert_raises(RuntimeError) { get "/t/#{@logia.slug}/dashboard", headers: NAVEGADOR }
    evento = Ahoy::Event.find_by!(name: "Petición")
    assert_equal 500, evento.properties["estado"]
    assert_equal "RuntimeError", evento.properties["error"]
    assert_equal 1, Ahoy::Event.errores.count
  ensure
    DashboardController.skip_before_action :fallar_rastreo, raise: false
  end

  test "Denuncias y la red no se rastrean" do
    sign_in @yo
    get "/denuncias", headers: NAVEGADOR
    get "/red", headers: NAVEGADOR
    assert_equal 0, Ahoy::Visit.count
    assert_equal 0, Ahoy::Event.count
    assert_no_match 'name="rastreo"', response.body
  end

  test "el navegador manda sus eventos a la visita, y solo el layout de COMUNIA enciende el rastreo" do
    sign_in @yo
    get "/t/#{@logia.slug}/dashboard", headers: NAVEGADOR
    assert_match '<meta name="rastreo" content="on">', response.body
    visita = Ahoy::Visit.sole

    eventos = [{ id: SecureRandom.uuid, name: "Tiempo en vista", time: Time.current.iso8601,
                 properties: { page: "/t/#{@logia.slug}/dashboard", segundos: 40, segundos_visible: 35 } },
               { id: SecureRandom.uuid, name: "Error del navegador", time: Time.current.iso8601,
                 properties: { page: "/t/#{@logia.slug}/dashboard", tipo: "script", mensaje: "x is undefined" } }]
    post "/ahoy/events", params: { events_json: eventos.to_json, visit_token: visita.visit_token,
                                   visitor_token: visita.visitor_token }, headers: NAVEGADOR
    assert_response :ok
    assert_equal 2, visita.events.where(name: ["Tiempo en vista", "Error del navegador"]).count
  end

  test "el panel es del superadmin: ve a cada persona y su línea de tiempo" do
    sign_in @yo
    get "/t/#{@logia.slug}/dashboard", headers: NAVEGADOR
    get "/rastreo"
    assert_redirected_to root_path
    reset!

    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    super_admin = User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                               password: "password123", rol_ref: rol)
    sign_in super_admin
    get "/rastreo", headers: NAVEGADOR
    assert_response :ok
    assert_match @yo.nombre_completo, response.body
    assert_equal 0, Ahoy::Visit.where(user: super_admin).count, "el panel no se rastrea a sí mismo"

    get "/rastreo/personas/#{@yo.id}"
    assert_response :ok
    assert_match "dashboard#index", response.body
    assert_match "Chrome Mobile", response.body
  end

  test "abrir la invitación anota a quién era, sin el token" do
    @yo.update_columns(invitation_token: Devise.token_generator.digest(User, :invitation_token, "TOKEN123"),
                       invitation_sent_at: Time.current, invitation_created_at: Time.current)
    get "/invitacion?invitation_token=TOKEN123", headers: NAVEGADOR
    assert_response :ok
    evento = Ahoy::Event.find_by!(name: "Petición")
    assert_equal @yo.id, evento.properties["invitado_id"]
    assert_not_includes Ahoy::Event.pluck(:properties).to_json + Ahoy::Visit.pluck(:landing_page).join, "TOKEN123"
  end

  test "el panel enseña el resumen por día" do
    sign_in @yo
    get "/t/#{@logia.slug}/dashboard", headers: NAVEGADOR
    reset!
    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    sign_in User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", rol_ref: rol)
    get "/rastreo", headers: NAVEGADOR
    assert_match "Por día", response.body
    assert_match "Rastreo de hoy: 1 persona, sin errores", response.body
  end
end
