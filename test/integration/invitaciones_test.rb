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
    assert_includes response.body, "caduca el #{I18n.l(7.days.from_now.to_date, format: :long)}"
    assert_equal :invitado, @user.reload.acceso
    assert_not @user.reload.valid_password?("password123"), "la contraseña anterior deja de servir hasta aceptar"
    sign_out :user

    get enlace
    assert_response :ok
    assert_includes response.body, @user.username
    assert_equal "no-store", response.headers["Cache-Control"]

    token = CGI.unescape(enlace[/invitation_token=([^&]+)/, 1])
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

  test "si la respuesta del primer envío no llegó, reenviar el formulario lleva a entrar con la contraseña ya elegida" do
    token = CGI.unescape(invitar(@miembro)[/invitation_token=([^&]+)/, 1])
    sign_out :user
    patch "/invitacion", params: { user: { invitation_token: token, password: "una clave larga", password_confirmation: "una clave larga" } }
    assert_redirected_to "/bienvenida"
    sign_out :user

    patch "/invitacion", params: { user: { invitation_token: token, password: "otra clave larga", password_confirmation: "otra clave larga" } }
    assert_response :see_other
    follow_redirect!
    follow_redirect! while response.redirect?
    assert_includes response.body, "Este enlace ya se usó o caducó. Si ya elegiste tu contraseña, entra con tu usuario y esa contraseña"
    assert @user.reload.valid_password?("una clave larga"), "el reenvío no cambia la contraseña ya elegida"
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
      assert_equal :invitacion_caducada, @user.reload.acceso
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

  test "dos miembros solo con celular: aceptar una invitación no anula ni se queda la del otro" do
    celia = ficha(usuario("Celia", email: nil, celular: "3001110001", rol_ref: @user.rol_ref))
    ciro = ficha(usuario("Ciro", email: nil, celular: "3001110002", rol_ref: @user.rol_ref))
    de_celia = invitar(celia)
    de_ciro = invitar(ciro)
    sign_out :user

    aceptar(de_celia, "la clave de celia")
    assert_redirected_to "/bienvenida"
    sign_out :user
    get de_ciro
    assert_response :ok
    assert_includes response.body, ciro.user.username
    aceptar(de_ciro, "la clave de ciro")
    assert_redirected_to "/bienvenida"
    sign_out :user

    assert_equal [ciro.user.id], DeviseInvitable::Invitation.accepted.where(invitable: ciro.user).pluck(:invitable_id)
    assert_nil ciro.user.reload.email
    post "/login", params: { user: { email: "300 111 0002", password: "la clave de ciro" } }
    assert_redirected_to "/dashboard"
  end

  test "quien ya había entrado: el enlace nuevo lo deja en espera y guarda la contraseña que elige" do
    @user.update_column(:last_seen_at, 3.days.ago)
    enlace = invitar(@miembro)
    sign_out :user
    post "/login", params: { user: { email: @user.username, password: "password123" } }
    assert_not_equal "/dashboard", URI(response.location.to_s).path, "la contraseña anterior no entra hasta aceptar"

    aceptar(enlace, "una clave nueva larga")
    assert_redirected_to "/bienvenida"
    assert @user.reload.valid_password?("una clave nueva larga")
    assert_not @user.valid_password?("password123")
  end

  test "un enlace de la 2.x que la migración pasó a devise_invitations sigue sirviendo" do
    # Lo que deja UpgradeUsersDeviseInvitations: el resumen del token, la clave (id) y las fechas de la 2.x.
    DeviseInvitable::Invitation.create!(
      invitable: @user, invited_by: @admin, invite_key: { "id" => @user.id },
      invitation_token: Devise.token_generator.digest(User, :invitation_token, "LEGADO2x"),
      invitation_created_at: 2.days.ago, invitation_sent_at: 2.days.ago, resource_created_at: 2.days.ago
    )
    get "/invitacion?invitation_token=LEGADO2x"
    assert_response :ok
    assert_includes response.body, @user.username
    aceptar("invitation_token=LEGADO2x", "una clave de antes")
    assert_redirected_to "/bienvenida"
    assert @user.reload.valid_password?("una clave de antes")
  end

  test "el enlace sigue sirviendo si al copiarlo se descodificó y el «+» llegó como espacio" do
    token = nil
    token = CGI.unescape(invitar(@miembro)[/invitation_token=([^&]+)/, 1]) until token&.include?("+")
    sign_out :user
    get "/invitacion?invitation_token=#{token}"
    assert_response :ok
    assert_includes response.body, @user.username
    aceptar("invitation_token=#{token.tr('+', ' ')}", "una clave larga")
    assert_redirected_to "/bienvenida"
  end

  test "un token alterado o de otro tipo de cuenta no sirve" do
    token = CGI.unescape(invitar(@miembro)[/invitation_token=([^&]+)/, 1])
    sign_out :user
    otro = token.sub(/\A./) { _1 == "A" ? "B" : "A" }
    get "/invitacion?#{{ invitation_token: otro }.to_query}"
    assert_response :redirect
    aceptar("invitation_token=#{CGI.escape(otro)}", "una clave larga")
    assert_response :see_other
    assert_nil @user.reload.invitation_accepted_at

    patch "/invitacion", params: { user: "texto" }
    assert_response :see_other
    get "/invitacion?invitation_token[a]=b"
    assert_response :redirect
    patch "/invitacion", params: { user: { invitation_token: { a: "b" }, password: "una clave larga" } }
    assert_response :see_other
  end

  test "aceptar la invitación de una comunidad no abre otra" do
    otra = Logia.create!(nombre: "Otra", slug: "otra-#{SecureRandom.hex(3)}", codigo: "OT#{rand(10_000)}")
    ajena = ficha(usuario("Ana", logia: otra))
    enlace = invitar(@miembro)
    sign_out :user
    aceptar(enlace, "una clave larga")
    assert_redirected_to "/bienvenida"

    get "/miembros/#{ajena.id}"
    assert_response :not_found
    assert_equal [@logia.organizacion.id], @user.reload.pertenencias.pluck(:organizacion_id).uniq
  end

  test "borrar la cuenta deja sin valor su enlace y no crea otra" do
    enlace = invitar(@miembro)
    sign_out :user
    @user.destroy!
    get enlace
    assert_response :redirect
    assert_no_difference -> { User.count } do
      aceptar(enlace, "una clave larga")
    end
    assert DeviseInvitable::Invitation.where(invitable_id: nil).all?(&:revoked_at)
  end

  test "más de 20 intentos por hora desde la misma IP se cortan" do
    anterior = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    20.times do |i|
      get "/invitacion?invitation_token=intento#{i}"
      assert_not_equal 429, response.status
    end
    get "/invitacion?invitation_token=uno-mas"
    assert_response 429
  ensure
    Rack::Attack.cache.store = anterior
  end

  private

  def aceptar(enlace, clave)
    token = CGI.unescape(enlace[/invitation_token=([^&]+)/, 1])
    patch "/invitacion", params: { user: { invitation_token: token, password: clave, password_confirmation: clave } }
  end

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
