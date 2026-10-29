require "test_helper"

# Pedir acceso con el código de la comunidad: quien lo pide crea su cuenta (en espera, no entra) con una
# prueba de pertenencia, y un administrador de esa logia lo aprueba dándole una ficha sin acceso (o una
# nueva) o lo rechaza. Ningún administrador resuelve solicitudes ni cambia códigos de otra comunidad.
class SolicitudesAccesoTest < ActionDispatch::IntegrationTest
  setup do
    @logia = Logia.create!(nombre: "Club Acceso", slug: "acceso-#{SecureRandom.hex(3)}", codigo: "AC#{rand(10_000)}")
    @logia.renovar_codigo_acceso!
    rol_admin = Rol.create!(nombre: "Admin acceso #{SecureRandom.hex(2)}", codigo: "admin_acceso_#{SecureRandom.hex(2)}")
    %w[index show create update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @admin = usuario("Ada", rol: :admin_logia, rol_ref: rol_admin)
    @nuevo = ficha(usuario("Nora"))
    @veterano = ficha(usuario("Vito", last_seen_at: 2.days.ago))
  end

  test "pedir acceso crea la cuenta en espera, avisa al admin y no deja entrar" do
    get "/login"
    assert_includes response.body, "Pide acceso"

    assert_difference -> { User.count } => 1, -> { SolicitudAcceso.count } => 1 do
      pedir(codigo: @logia.codigo_acceso_legible.downcase)
    end
    assert_redirected_to "/pedir-acceso/enviada"
    follow_redirect!
    assert_includes response.body, @logia.nombre_display

    solicitud = SolicitudAcceso.last
    assert solicitud.pendiente?
    assert_equal [@logia, "nora.nueva@correo.co"], [solicitud.logia, solicitud.email]
    assert solicitud.user.espera_aprobacion?
    assert_nil solicitud.user.logia, "en espera no aparece en la logia"
    aviso = @admin.notificaciones.last
    assert_equal ["solicitud_acceso", "/solicitudes/#{solicitud.id}"], [aviso.tipo, aviso.url]

    post "/login", params: { user: { email: "nora.nueva@correo.co", password: "clave-segura-1" } }
    assert_redirected_to "/login"
    follow_redirect!
    assert_includes response.body, "espera la aprobación"
  end

  test "sin código válido, con correo ya usado o sin aceptar, no se crea nada" do
    assert_no_difference -> { User.count } do
      pedir(codigo: "AAA-AAA")
      assert_response :unprocessable_content
      assert_includes response.body, "no corresponde a ninguna comunidad"
      pedir(email: @nuevo.user.email)
      assert_includes response.body, "ya tiene cuenta"
      pedir(acepto: "0")
      assert_includes response.body, "política de datos"
      pedir(codigo: { x: 1 }, prueba: ["a"])
      assert_response :unprocessable_content
    end
  end

  test "aprobar con su ficha: la ficha toma su correo y su contraseña, la cuenta en espera desaparece" do
    solicitud = solicitar
    espera = solicitud.user

    sign_in @admin
    get "/solicitudes/#{solicitud.id}"
    assert_response :ok
    assert_includes response.body, %(value="#{@nuevo.id}")
    assert_not_includes response.body, %(value="#{@veterano.id}"), "quien ya entró no se ofrece"

    post "/solicitudes/#{solicitud.id}/aprobar", params: { miembro_id: @veterano.id.to_s }
    assert_redirected_to "/solicitudes/#{solicitud.id}"
    assert solicitud.reload.pendiente?

    post "/solicitudes/#{solicitud.id}/aprobar", params: { miembro_id: @nuevo.id.to_s }
    assert_redirected_to "/solicitudes"
    assert solicitud.reload.aprobada?
    assert_equal [@nuevo, @nuevo.user, @admin], [solicitud.miembro, solicitud.user, solicitud.decidida_por]
    assert_not User.exists?(espera.id)
    assert_equal "nora.nueva@correo.co", @nuevo.user.reload.email

    sign_out :user
    post "/login", params: { user: { email: "nora.nueva@correo.co", password: "clave-segura-1" } }
    assert_redirected_to "/dashboard"
  end

  test "aprobar con una ficha nueva" do
    solicitud = solicitar
    sign_in @admin
    assert_difference -> { Miembro.count } => 1 do
      post "/solicitudes/#{solicitud.id}/aprobar", params: { ficha: "nueva", cedula: "998877", numero_miembro: "N-998" }
    end
    miembro = solicitud.reload.miembro
    assert_equal [@logia, solicitud.user, "998877"], [miembro.logia, miembro.user, miembro.cedula]
    assert_not miembro.user.espera_aprobacion?
    assert_not miembro.user.solo_red?

    sign_out :user
    post "/login", params: { user: { email: "nora.nueva@correo.co", password: "clave-segura-1" } }
    assert_redirected_to "/dashboard"
  end

  test "rechazar borra la cuenta en espera" do
    solicitud = solicitar
    sign_in @admin
    post "/solicitudes/#{solicitud.id}/rechazar", params: { motivo: "No la conocemos" }
    assert solicitud.reload.rechazada?
    assert_equal "No la conocemos", solicitud.motivo
    assert_not User.exists?(email: "nora.nueva@correo.co")
    post "/solicitudes/#{solicitud.id}/aprobar", params: { miembro_id: @nuevo.id.to_s }
    assert_redirected_to "/solicitudes/#{solicitud.id}"
    assert_not_equal "nora.nueva@correo.co", @nuevo.user.reload.email
  end

  test "el código se crea y se cambia, y el anterior deja de servir" do
    sign_in @admin
    get "/solicitudes"
    assert_includes response.body, @logia.codigo_acceso_legible
    anterior = @logia.codigo_acceso
    post "/solicitudes/codigo", params: { logia_id: @logia.id }
    assert_not_equal anterior, @logia.reload.codigo_acceso
    assert_nil Logia.por_codigo_acceso(anterior)
    assert_equal @logia, Logia.por_codigo_acceso(@logia.codigo_acceso_legible)
  end

  test "otra comunidad y un miembro raso no ven ni resuelven" do
    solicitud = solicitar
    otra = Logia.create!(nombre: "Otra", slug: "otra-#{SecureRandom.hex(3)}", codigo: "OT#{rand(10_000)}")
    otra.renovar_codigo_acceso!
    ajeno = usuario("Ugo", logia: otra, rol: :admin_logia, rol_ref: @admin.rol_ref)

    # Con un 404 la sesión de prueba no se guarda: se entra antes de cada petición.
    [[:get, "/solicitudes/#{solicitud.id}"], [:post, "/solicitudes/#{solicitud.id}/rechazar"],
     [:post, "/solicitudes/#{solicitud.id}/aprobar", { miembro_id: @nuevo.id.to_s }],
     [:post, "/solicitudes/codigo", { logia_id: @logia.id }]].each do |verbo, ruta, params|
      sign_in ajeno
      send(verbo, ruta, params: params)
      assert_response :not_found
    end
    assert solicitud.reload.pendiente?

    sign_in @nuevo.user
    get "/solicitudes"
    assert_redirected_to "/"
    post "/solicitudes/#{solicitud.id}/aprobar", params: { miembro_id: @nuevo.id.to_s }
    assert solicitud.reload.pendiente?
  end

  private

  def pedir(**cambios)
    post "/pedir-acceso", params: { codigo: @logia.codigo_acceso, nombre: "Nora", apellido: "Nueva", email: "nora.nueva@correo.co",
                                    password: "clave-segura-1", password_confirmation: "clave-segura-1",
                                    prueba: "Soy la socia 45 desde 2019, me presentó Ada.", acepto: "1" }.merge(cambios)
  end

  def solicitar
    pedir
    SolicitudAcceso.last
  end

  def usuario(nombre, logia: @logia, **attrs)
    User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                 password: "password123", logia: logia, **{ rol: :miembro, rol_ref: @rol_miembro }.merge(attrs))
  end

  def ficha(user, **attrs)
    Miembro.create!(user: user, logia: user.logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4),
                    estado: :activo, **attrs)
  end
end
