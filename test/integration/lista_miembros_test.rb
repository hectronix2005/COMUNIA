require "test_helper"

# Lista de miembros: tabla en escritorio y tarjetas en el móvil, con editar a la vista y desactivar en el menú.
# La columna del grupo solo sale si la lista mezcla varios.
class ListaMiembrosTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.create!(nombre: "Admin lista #{SecureRandom.hex(2)}", codigo: "admin_lista_#{SecureRandom.hex(2)}")
    %w[index show update].each { @rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro", modulos: %w[reuniones])
    @mercedes = Logia.create!(nombre: "Mercedes", slug: "mercedes-#{SecureRandom.hex(3)}",
                              codigo: "L#{SecureRandom.hex(3).upcase}", categoria: @club)
    @admin = persona("Ada", rol_ref: @rol_admin)
    @nora = persona("Nora")
  end

  test "cada miembro sale en la tabla y en su tarjeta, sin columna de grupo si solo hay uno" do
    sign_in @admin
    get "/miembros"
    assert_response :ok
    assert_select "table.tabla-miembros tbody tr", 2
    assert_select ".d-md-none .card", 2
    assert_select "table.tabla-miembros th", text: @mercedes.t_logia, count: 0
    assert_select "table.tabla-miembros .badge.bg-light", text: "Nunca ha entrado"
    assert_select ".dropdown-menu a[href=?]", "/miembros/#{@nora.miembro.id}/cambiar_estado", text: "Desactivar"
  end

  private

  def persona(nombre, rol_ref: @rol_miembro)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @mercedes, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    Miembro.create!(user: user, logia: @mercedes, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
