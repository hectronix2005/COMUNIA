require "test_helper"

# Una cuenta de la red no tiene logia, y el resto de COMUNIA cae a la primera logia cuando falta la del
# usuario: si una cuenta de la red pudiera abrir cualquier pantalla de logias, vería datos de otra.
class Red::ConfinamientoTest < ActionDispatch::IntegrationTest
  include RedPrueba

  setup do
    @logia = Logia.create!(nombre: "Logia Ajena", slug: "ajena-#{SecureRandom.hex(3)}", codigo: "AJ#{rand(10_000)}")
    @persona = red_usuario("Ana")
    sign_in @persona
  end

  test "ninguna pantalla GET fuera de /red abre para una cuenta de la red" do
    rutas = Rails.application.routes.routes.filter_map do |r|
      next unless r.verb.to_s.include?("GET")
      ruta = r.path.spec.to_s.sub("(.:format)", "")
      controlador = r.defaults[:controller].to_s
      next if controlador.blank? || controlador.start_with?("red/", "denuncias/", "rails/", "active_storage", "action_mailbox", "devise")
      next if controlador.in?(ApplicationController::CONTROLADORES_PARA_CUENTAS_RED)
      next unless "#{controlador.camelize}Controller".safe_constantize&.<=(ApplicationController)
      next if r.path.spec.to_s.include?("*")
      ruta.gsub(/\(.*?\)/, "").gsub(/:[a-z_]+/, "1")
    end.uniq
    assert_operator rutas.size, :>, 50, "se revisan las rutas de la app de logias"

    abiertas = rutas.reject do |ruta|
      get ruta
      response.not_found? || (response.redirect? && URI(response.location).path == "/red")
    end
    assert_empty abiertas, "Pantallas que abren para una cuenta de la red"
  end

  test "una cuenta de la red entra con su correo; la de una logia, no" do
    sign_out @persona
    post "/red/entrar", params: { user: { email: @persona.email, password: RedPrueba::CLAVE } }
    assert_redirected_to "/red"

    sign_out @persona
    de_logia = User.create!(nombre: "L", apellido: "M", email: "l_#{SecureRandom.hex(3)}@x.co", password: "password123", logia: @logia)
    assert_nil User.find_for_database_authentication(email: de_logia.email)
  end

  test "la portada abre sin cuenta y con cuenta enseña el tablón" do
    sign_out @persona
    get "/red"
    assert_response :ok
    assert_select "h1", /Gente de confianza/
    sign_in @persona
    get "/red"
    assert_response :ok
    assert_select "h1", "Tablón"
  end

  test "quien es de una logia llega a la red desde el menú y puede volver; la cuenta de la red no ve la vuelta" do
    get "/red"
    assert_not_includes response.body, "Volver a COMUNIA"

    de_logia = User.create!(nombre: "L", apellido: "M", email: "l_#{SecureRandom.hex(3)}@x.co", password: "password123", logia: @logia)
    sign_in de_logia
    get "/dashboard"
    follow_redirect! if response.redirect? # al de su logia: /t/<slug>/dashboard
    assert_response :ok
    assert_select "a.nav-link[href='/red']" # sin /t/<slug>: un enlace copiado no delata la organización
    get "/red/bienvenida"
    assert_response :ok
    assert_select "a[href='/']", "Volver a COMUNIA"
    get "/red/mi-perfil"
    assert_redirected_to "/red/bienvenida"
  end

  test "la red nunca se sirve bajo el prefijo de un tenant" do
    get "/t/#{@logia.slug}/red/buscar?q=nevera"
    assert_response :moved_permanently
    assert_equal "/red/buscar?q=nevera", response.location.delete_prefix("http://www.example.com")
    post "/t/#{@logia.slug}/red/p/abc/reportar"
    assert_response :not_found
    get "/t/#{@logia.slug}/redes"
    assert_not_equal 301, response.status
  end

  test "si la sesión caduca dentro de la red, se vuelve al login de la red" do
    sign_in red_usuario("Ana")
    get "/red/mi-perfil"
    assert_response :success
    travel 5.hours do
      get "/red/mi-perfil" # Devise vuelve a pedir la misma página, ya sin sesión
      follow_redirect!
      assert_redirected_to "/red/entrar"
      post "/red/mi-perfil", params: { _method: "patch", nombre_publico: "X" }
      assert_redirected_to "http://www.example.com/red/entrar"
    end
  end
end
