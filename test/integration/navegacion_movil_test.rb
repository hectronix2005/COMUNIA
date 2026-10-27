require "test_helper"

# Navegación del móvil: barra inferior con los destinos de cada día, «Cumpleaños» una sola vez en el menú y, en
# Reuniones sin nada convocado, los próximos eventos del calendario en vez de una página vacía.
class NavegacionMovilTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria ayuda])
    @logia = Logia.create!(nombre: "Ruta", slug: "ruta-#{SecureRandom.hex(3)}", codigo: "L#{SecureRandom.hex(3).upcase}",
                           categoria: @club)
    @socio = User.create!(nombre: "Sara", apellido: "Prueba", email: "sara_#{SecureRandom.hex(3)}@correo.co",
                          password: "password123", logia: @logia, rol_ref: @rol_miembro, rol: :miembro)
    Miembro.create!(user: @socio, logia: @logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: :activo)
    @base = "/t/#{@logia.slug}"
  end

  test "la barra inferior lleva Inicio, Agenda, Muro, Chat y Menú, y marca dónde se está" do
    sign_in @socio
    get "#{@base}/dashboard"
    barra = response.body[%r{<nav class="barra-inferior.*?</nav>}m]
    assert barra, "falta la barra inferior"
    %w[Inicio Agenda Muro Chat Menú].each { assert_includes barra, _1 }
    assert_match(/aria-current="page"[^>]*>\s*<i class="bi bi-house"/, barra)
    assert_equal 1, response.body.scan("bi-balloon-heart me-2").size, "Cumpleaños sale una sola vez en el menú"
  end

  test "sin nada convocado, Reuniones enseña los próximos eventos del calendario" do
    CalendarioEvento.create!(logia: @logia, user: @socio, titulo: "Cena de fin de año",
                              inicio: 3.days.from_now.change(hour: 20), fin: 3.days.from_now.change(hour: 22))
    sign_in @socio
    get "#{@base}/reuniones"
    assert_includes response.body, "Nada convocado por ahora como encuentro."
    assert_includes response.body, "Cena de fin de año"
  end
end
