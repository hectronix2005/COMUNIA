require "test_helper"

# Tesorería y Biblioteca van juntas en el menú «Herramientas» (1-nov-2026), como Muro, Chat y demás van en
# «Comunidad»: la barra cabe en una fila.
class MenuHerramientasTest < ActionDispatch::IntegrationTest
  setup do
    @logia = Logia.create!(nombre: "Logia Menú", slug: "menu-#{SecureRandom.hex(3)}", codigo: "M#{SecureRandom.hex(3).upcase}")
    @user = User.create!(nombre: "Ana", apellido: "Menú", email: "ana_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                         logia: @logia, rol_ref: Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" })
    Miembro.create!(user: @user, logia: @logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
  end

  test "Tesorería y Biblioteca salen dentro de Herramientas, no como menús sueltos" do
    sign_in @user
    get "/dashboard"
    follow_redirect! while response.redirect?
    assert_response :ok

    assert_select ".navbar-main .nav-item.dropdown > .dropdown-toggle", text: /Tesorer|Biblioteca/, count: 0
    assert_select ".navbar-main .nav-item.dropdown", { text: /Herramientas/, count: 1 } do
      assert_select ".dropdown-header", text: "TESORERÍA"
      assert_select ".dropdown-header", text: "BIBLIOTECA"
      assert_select "a[href*='/biblioteca/libros']", 1
      assert_select "a[href*='mis-cobros']", 1
    end
  end
end
