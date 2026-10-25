require "test_helper"

# La página de login es pública: no puede listar usuarios ni sugerir contraseñas. Hasta el 25-oct-2026
# mostraba «credenciales de demostración» con los usuarios reales y contraseñas fijas.
class LoginPublicoTest < ActionDispatch::IntegrationTest
  test "el login, con o sin tenant, no enseña usuarios ni contraseñas" do
    logia = Logia.create!(nombre: "Logia Login", slug: "login-#{SecureRandom.hex(3)}", codigo: "LG#{rand(10_000)}")
    user = User.create!(nombre: "Ana", apellido: "Visible", email: "ana_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" })

    ["/login", "/t/#{logia.slug}/login"].each do |ruta|
      get ruta
      assert_response :ok, ruta
      assert_not_includes response.body, user.username, ruta
      assert_not_includes response.body, "data-password", ruta
      assert_not_includes response.body, "password123", ruta
    end
  end
end
