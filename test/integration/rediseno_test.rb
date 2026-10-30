require "test_helper"

# Rediseño del 29-oct-2026: portada pública, ingreso a dos paneles, guía y recorrido guiado. El recorrido arranca
# solo hasta que se termina u omite (users.recorrido_visto_at); el invitado de la demostración no lo guarda.
class RedisenoTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @logia = Logia.create!(nombre: "Club Diseño", slug: "diseno-#{SecureRandom.hex(3)}", codigo: "D#{SecureRandom.hex(3).upcase}")
    @socio = User.create!(nombre: "Lina", apellido: "Prueba", email: "lina_#{SecureRandom.hex(3)}@correo.co",
                          password: "password123", logia: @logia, rol_ref: @rol_miembro)
    Miembro.create!(user: @socio, logia: @logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
  end

  test "la portada es pública y lleva a ingresar" do
    get "/"
    assert_response :ok
    assert_includes response.body, "Tu comunidad, <em>en un solo lugar.</em>"
    assert_includes response.body, 'href="/login"'
  end

  test "con sesión la portada lleva al inicio y dentro de una comunidad al ingreso" do
    get "/t/#{@logia.slug}/"
    assert_redirected_to "/t/#{@logia.slug}/login"

    sign_in @socio
    get "/"
    assert_redirected_to "/dashboard"
  end

  test "el ingreso de una comunidad muestra su nombre junto al formulario" do
    get "/t/#{@logia.slug}/login"
    assert_response :ok
    assert_select ".ingreso .ingreso-nombre", text: /Club Diseño/
    assert_select ".ingreso .login-card #login-username"
    assert_select ".ingreso .login-card #login-password"
  end

  test "la guía enseña lo de la comunidad y el botón para repetir el recorrido" do
    sign_in @socio
    get "/t/#{@logia.slug}/guia"
    assert_response :ok
    assert_select "[data-recorrido=guia]"
    assert_select "button[data-action='recorrido#empezar']"
    assert_select ".guia-item h3", text: "Muro"
    assert_select ".guia-item h3", text: "Roles", count: 0
  end

  test "el recorrido arranca solo hasta que se termina" do
    sign_in @socio
    get "/t/#{@logia.slug}/dashboard"
    assert_select "body[data-controller=recorrido][data-recorrido-automatico-value=true]"
    assert_select "[data-recorrido=saludo]"
    pasos = JSON.parse(css_select("body").first["data-recorrido-pasos-value"])
    assert_equal "/t/#{@logia.slug}/dashboard", pasos.first["ruta"]
    assert_equal "guia", pasos.last["foco"]

    patch "/t/#{@logia.slug}/recorrido"
    assert_response :no_content
    assert @socio.reload.recorrido_visto_at

    get "/t/#{@logia.slug}/dashboard"
    assert_select "body[data-recorrido-automatico-value=false]"
  end

  test "el invitado de la demostración no guarda el recorrido" do
    Demo.preparar!
    post "/demo"
    get "/t/#{Demo::SLUG}/dashboard"
    follow_redirect! while response.redirect?
    assert_select "body[data-recorrido-automatico-value=true][data-recorrido-marcar-url-value='']"
    assert_nil Demo.invitado.reload.recorrido_visto_at
  end

  test "el color de la comunidad solo admite un hexadecimal" do
    @logia.color_primario = "red;}</style><script>alert(1)</script>"
    assert_not @logia.valid?
    assert_includes @logia.errors[:color_primario], "debe ser un color como #0D3436"

    @logia.color_primario = "#0d3436"
    assert @logia.valid?
    assert_equal "#0d3436", @logia.color_display

    @logia.color_primario = "nada"
    assert_equal "#0D3436", @logia.color_display
  end
end
