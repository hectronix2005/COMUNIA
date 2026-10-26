require "test_helper"

# Invitaciones: un admin genera desde la ficha un enlace de un solo uso (se manda por WhatsApp), el
# miembro elige ahí su contraseña y entra. Generar un enlace es poder entrar en esa cuenta, así que solo
# se puede para miembros rasos de las logias propias.
class InvitacionesTest < ActionDispatch::IntegrationTest
  setup do
    @logia = Logia.create!(nombre: "Logia Invita", slug: "invita-#{SecureRandom.hex(3)}", codigo: "IN#{rand(10_000)}")
    rol_admin = Rol.create!(nombre: "Admin invita #{SecureRandom.hex(2)}", codigo: "admin_invita_#{SecureRandom.hex(2)}")
    %w[index show update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    @admin = usuario("Ada", rol: :admin_logia, rol_ref: rol_admin)
    @user = usuario("Mario", rol: :miembro, rol_ref: Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" })
    @miembro = ficha(@user, telefono: "300 123 4567")
  end

  test "el admin genera el enlace, el miembro elige contraseña, entra y el enlace no vuelve a servir" do
    enlace = invitar(@miembro)
    assert_includes response.body, "wa.me/573001234567?text="
    assert_not @user.reload.valid_password?("password123"), "la contraseña anterior deja de servir hasta aceptar"
    sign_out :user

    get enlace
    assert_response :ok
    assert_includes response.body, @user.username
    assert_equal "no-store", response.headers["Cache-Control"]

    token = enlace[/invitation_token=([^&]+)/, 1]
    patch "/invitacion", params: { user: { invitation_token: token, password: "corta", password_confirmation: "corta" } }
    assert_response :unprocessable_entity
    assert_nil @user.reload.invitation_accepted_at

    patch "/invitacion", params: { user: { invitation_token: token, password: "una clave larga", password_confirmation: "una clave larga" } }
    assert_redirected_to "/bienvenida"
    follow_redirect!
    assert_response :ok
    assert_includes response.body, @user.username
    assert @user.reload.invitation_accepted_at
    assert @user.valid_password?("una clave larga")

    sign_out :user
    get enlace
    assert_response :redirect
  end

  test "la bienvenida lleva al próximo encuentro con su respuesta y al calendario del teléfono" do
    inicio = 3.days.from_now.change(hour: 19)
    evento = CalendarioEvento.create!(logia: @logia, user: @admin, titulo: "Encuentro de octubre", inicio: inicio, fin: inicio + 2.hours)
    sign_in @user
    get "/bienvenida"
    assert_response :ok
    assert_includes response.body, "Encuentro de octubre"
    assert_includes response.body, "/calendario/#{evento.id}/evento_confirmaciones?estado=confirmado"
    assert_includes response.body, %(href="/calendario/suscripcion")
    assert_no_match(/logia/i, response.body[/Avisos en el celular.*?<\/p>/m])
  end

  test "el enlace caduca a los 7 días" do
    enlace = invitar(@miembro)
    sign_out :user
    travel 7.days + 1.minute do
      get enlace
      assert_response :redirect
    end
  end

  test "generar otro enlace deja sin valor el anterior" do
    primero = invitar(@miembro)
    segundo = invitar(@miembro)
    sign_out :user
    get primero
    assert_response :redirect
    get segundo
    assert_response :ok
  end

  test "solo para miembros rasos de las logias propias, y nunca la propia cuenta" do
    otro_admin = ficha(usuario("Otto", rol: :admin_logia, rol_ref: @admin.rol_ref))
    propia = ficha(@admin)
    ajena = ficha(usuario("Ana", rol: :miembro, logia: Logia.create!(nombre: "Otra", slug: "otra-#{SecureRandom.hex(3)}", codigo: "OT#{rand(10_000)}")))

    [otro_admin, propia].each do |m|
      sign_in @admin
      post "/miembros/#{m.id}/invitar"
      assert_nil m.user.reload.invitation_token, m.user.nombre
    end
    sign_in @admin
    post "/miembros/#{ajena.id}/invitar"
    assert_response :not_found
    assert_nil ajena.user.reload.invitation_token

    sign_in @user
    post "/miembros/#{@miembro.id}/invitar"
    assert_nil @user.reload.invitation_token
  end

  test "las rutas de la gema para invitar por correo o borrar la cuenta no existen" do
    sign_in @admin
    ["/invitation/new", "/invitation/remove?invitation_token=x", "/users/invitation/new"].each do |ruta|
      get ruta
      assert_response :not_found, ruta
    end
  end

  test "con una invitación pendiente, el login responde igual que con un usuario que no existe" do
    invitar(@miembro)
    sign_out :user
    respuestas = [@user.username, "nadie#{SecureRandom.hex(3)}"].map do |login|
      post "/login", params: { user: { email: login, password: "password123" } }
      [response.status, flash[:alert]]
    end
    assert_equal respuestas.first, respuestas.last
  end

  private

  def usuario(nombre, logia: @logia, **attrs)
    User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                 password: "password123", logia: logia, **attrs)
  end

  def ficha(user, **attrs)
    Miembro.create!(user: user, logia: user.logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4),
                    estado: :activo, **attrs)
  end

  def invitar(miembro)
    sign_in @admin
    post "/miembros/#{miembro.id}/invitar"
    assert_redirected_to %r{/miembros/#{miembro.id}}
    follow_redirect!
    assert_response :ok
    response.body[%r{https?://[^"]+/invitacion\?invitation_token=[^"&]+}]&.then { URI(_1).request_uri } || flunk("sin enlace")
  end
end
