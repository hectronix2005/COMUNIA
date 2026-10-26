require "test_helper"

# Invitar en bloque: desde una sola página, el admin ve a los miembros activos que aún no han entrado, apunta
# su celular y genera de una vez los enlaces para mandarlos por WhatsApp. Quien ya entró, un admin o alguien
# de otra comunidad nunca aparece, porque generar un enlace es poder entrar en esa cuenta.
class InvitarEnBloqueTest < ActionDispatch::IntegrationTest
  setup do
    @logia = Logia.create!(nombre: "Club Bloque", slug: "bloque-#{SecureRandom.hex(3)}", codigo: "BL#{rand(10_000)}")
    rol_admin = Rol.create!(nombre: "Admin bloque #{SecureRandom.hex(2)}", codigo: "admin_bloque_#{SecureRandom.hex(2)}")
    %w[index show update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @admin = usuario("Ada", rol: :admin_logia, rol_ref: rol_admin)
    @nuevo = ficha(usuario("Nora"))
    @sin_cel = ficha(usuario("Sara"))
    @veterano = ficha(usuario("Vito", last_seen_at: 2.days.ago))
  end

  test "lista solo a quienes faltan, guarda el celular y genera los enlaces de los marcados" do
    otro_admin = ficha(usuario("Otto", rol: :admin_logia, rol_ref: @admin.rol_ref))
    inactivo = ficha(usuario("Iris"), estado: :quite, estado_desde: Date.current)
    ajeno = ficha(usuario("Ana", logia: Logia.create!(nombre: "Otra", slug: "otra-#{SecureRandom.hex(3)}", codigo: "OT#{rand(10_000)}")))

    sign_in @admin
    get "/miembros/acceso"
    assert_response :ok
    assert_includes response.body, "Invitar a #{@nuevo.user.nombre_completo}"
    assert_includes response.body, "Invitar a #{@sin_cel.user.nombre_completo}"
    [@veterano, otro_admin, inactivo, ajeno, ficha(@admin)].each do |m|
      assert_not_includes response.body, "Invitar a #{m.user.nombre_completo}"
    end

    post "/miembros/acceso", params: { ids: [@nuevo.id.to_s, @veterano.id.to_s, ajeno.id.to_s],
                                       telefonos: { @nuevo.id.to_s => " 300 765 4321 ", @sin_cel.id.to_s => "+57 310 000 0000" } }
    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "wa.me/573007654321?text="
    assert_equal "300 765 4321", @nuevo.reload.telefono
    assert_equal "+57 310 000 0000", @sin_cel.reload.telefono, "el celular se guarda aunque no se le invite"

    assert @nuevo.user.reload.invitation_token
    assert_nil @sin_cel.user.reload.invitation_token, "sin marcar no se invita"
    assert_nil @veterano.user.reload.invitation_token, "quien ya entró no se invita aunque llegue su id"
    assert_nil ajeno.user.reload.invitation_token
    assert_nil otro_admin.user.reload.invitation_token

    enlace = response.body[%r{https?://[^"\s]+/invitacion\?invitation_token=[^"&\s]+}] || flunk("sin enlace")
    sign_out :user
    get URI(enlace).request_uri
    assert_response :ok
    assert_includes response.body, @nuevo.user.username
  end

  test "un celular mal escrito no guarda nada ni genera enlaces" do
    sign_in @admin
    post "/miembros/acceso", params: { ids: [@nuevo.id.to_s], telefonos: { @nuevo.id.to_s => "300 123 4567",
                                                                           @sin_cel.id.to_s => "<script>" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "No se guardó nada"
    assert_nil @nuevo.reload.telefono
    assert_nil @nuevo.user.reload.invitation_token
  end

  test "sin marcar a nadie vuelve a la lista" do
    sign_in @admin
    post "/miembros/acceso", params: { telefonos: { @nuevo.id.to_s => "300 111 2222" } }
    assert_redirected_to "/miembros/acceso"
    assert_equal "300 111 2222", @nuevo.reload.telefono
  end

  test "un miembro raso no entra ni invita" do
    sign_in @nuevo.user
    get "/miembros/acceso"
    assert_redirected_to "/"
    post "/miembros/acceso", params: { ids: [@sin_cel.id.to_s] }
    assert_nil @sin_cel.user.reload.invitation_token
  end

  test "la lista de miembros enlaza a la página mientras falte alguien" do
    sign_in @admin
    get "/miembros"
    assert_includes response.body, "Invitar a quienes faltan"
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
