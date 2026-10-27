require "test_helper"

# «Quién usa la app» en el panel del admin: de los miembros activos, cuántos han entrado, cuántos tienen la
# invitación sin usar y cuántos faltan por invitar, con el enlace a invitar en bloque.
class AdopcionPanelTest < ActionDispatch::IntegrationTest
  setup do
    @logia = Logia.create!(nombre: "Vecinos Cedritos", slug: "cedritos-#{SecureRandom.hex(3)}", codigo: "CE#{rand(10_000)}")
    rol_admin = Rol.create!(nombre: "Admin vecinos #{SecureRandom.hex(2)}", codigo: "admin_vecinos_#{SecureRandom.hex(2)}")
    %w[index show update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @admin = usuario("Ada", rol: :admin_logia, rol_ref: rol_admin, last_seen_at: 1.hour.ago)
    ficha(@admin)
    ficha(usuario("Vito", last_seen_at: 2.days.ago))
    ficha(usuario("Viejo", last_seen_at: 3.months.ago))
    ficha(usuario("Nora"))
    ficha(usuario("Ines")).user.invite! { _1.skip_invitation = true }
    ficha(usuario("Iris", last_seen_at: 1.day.ago), estado: :quite, estado_desde: Date.yesterday)
    ficha(usuario("Ana", logia: Logia.create!(nombre: "Otra", slug: "otra-#{SecureRandom.hex(3)}", codigo: "OT#{rand(10_000)}")))
  end

  test "cuenta solo a los activos de su comunidad y enlaza a invitar" do
    sign_in @admin
    get "/t/#{@logia.slug}/dashboard"
    assert_response :ok
    assert_match "Quién usa la app", response.body
    texto = response.body.gsub(/\s+/, " ")
    assert_match "3 de 5", texto
    assert_match "· 2 esta semana", texto
    assert_match "1 invitado sin entrar", texto
    assert_match "1 sin invitar", texto
    assert_includes response.body, %(href="/t/#{@logia.slug}/miembros/acceso")
  end

  test "un miembro raso no la ve" do
    sign_in User.find_by!(nombre: "Vito")
    get "/t/#{@logia.slug}/dashboard"
    assert_response :ok
    assert_no_match "Quién usa la app", response.body
  end

  private

  def usuario(nombre, logia: @logia, **attrs)
    User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                 password: "password123", logia: logia, **{ rol: :miembro, rol_ref: @rol_miembro }.merge(attrs))
  end

  def ficha(user, **attrs)
    Miembro.create!(user: user, logia: user.logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4),
                    estado: :activo, **attrs)
  end
end
