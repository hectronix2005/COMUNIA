require "test_helper"

# Un admin solo ve y toca los miembros de las logias que administra, aunque adivine el id de otro.
class MiembrosAlcanceTest < ActionDispatch::IntegrationTest
  test "un admin no abre ni edita miembros de otra logia" do
    propia = Logia.create!(nombre: "Logia Propia", slug: "propia-#{SecureRandom.hex(3)}", codigo: "PR#{rand(10_000)}")
    ajena  = Logia.create!(nombre: "Logia Ajena",  slug: "ajena-#{SecureRandom.hex(3)}",  codigo: "AJ#{rand(10_000)}")
    rol = Rol.create!(nombre: "Admin alcance #{SecureRandom.hex(2)}", codigo: "admin_alcance_#{SecureRandom.hex(2)}")
    %w[index show update].each { rol.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    admin = User.create!(nombre: "Ada", apellido: "Admin", email: "ada_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: propia, rol_ref: rol)
    otro = User.create!(nombre: "Otto", apellido: "Ajeno", email: "otto_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: ajena)
    miembro = Miembro.create!(user: otro, logia: ajena, numero_miembro: "N#{SecureRandom.hex(3)}",
                              cedula: SecureRandom.hex(4), estado: :activo)

    # Un 404 no guarda la cookie de sesión: se vuelve a entrar antes de cada petición.
    [[:get, "/miembros/#{miembro.id}"], [:get, "/miembros/#{miembro.id}/edit"],
     [:patch, "/miembros/#{miembro.id}", { miembro: { grado: "Cambiado" } }]].each do |verbo, ruta, params|
      sign_in admin
      send(verbo, ruta, params: params)
      assert_response :not_found, "#{verbo} #{ruta}"
    end
    assert_not_equal "Cambiado", miembro.reload.grado

    sign_in admin
    get "/miembros/#{admin_miembro(admin, propia).id}"
    assert_response :ok
  end

  private

  def admin_miembro(admin, logia)
    Miembro.create!(user: admin, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
  end
end
