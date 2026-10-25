require "test_helper"

# Fase 3: registro, certificación de comunidades y membresías con verificadores.
class Red::ComunidadesTest < ActionDispatch::IntegrationTest
  include RedPrueba

  setup { Red::Captcha.verificador = ->(t) { t == "ok" } }
  teardown { Red::Captcha.verificador = nil }

  def registrar(**extra)
    post "/red/registro", params: { nombre: "Ana", apellido: "Ruiz", email: "Ana@Correo.co", password: "una-clave-larga",
                                    password_confirmation: "una-clave-larga", acepto: "1", "cf-turnstile-response" => "ok" }.merge(extra)
  end

  test "registro: cuenta solo de la red, rol de miembro aunque el formulario pida otro" do
    registrar(rol: "super_admin", solo_red: "0", rol_ref_id: "1")
    assert_redirected_to "/red/bienvenida"
    u = User.find_by(email: "ana@correo.co")
    assert u.solo_red?
    assert u.miembro?
    assert_nil u.rol_ref_id
    assert_nil u.logia_id
  end

  test "registro: sin consentimiento, sin captcha o con campos raros no crea cuenta" do
    registrar(acepto: "0")
    assert_response :unprocessable_content
    registrar("cf-turnstile-response" => "malo")
    assert_response :unprocessable_content
    registrar(email: { "$ne" => "" })
    assert_response :unprocessable_content
    registrar(password: "corta", password_confirmation: "corta")
    assert_response :unprocessable_content
    assert_equal 0, User.where(solo_red: true).count
  end

  test "certificación: se pide, la plataforma certifica y quien la pidió queda de administrador" do
    ana = red_usuario("Ana")
    sign_in ana
    post "/red/comunidades", params: { nombre: "Club de Ajedrez Alfil", tipo_vinculo: "club", criterio: "Socios con carné del club",
                                       metodo_verificacion: "documento", evidencia: "NIT 900.000.000-1" }
    c = Red::Comunidad.find_by(nombre: "Club de Ajedrez Alfil")
    assert_equal "solicitada", c.estado
    get "/red/comunidades/#{c.token}"
    assert_response :ok, "quien la pidió la ve en revisión"

    otra = red_usuario("Otra")
    sign_in otra
    get "/red/comunidades/#{c.token}"
    assert_response :not_found
    post "/red/moderacion/comunidades/#{c.token}/certificar"
    assert_response :not_found, "solo la plataforma certifica"

    sign_in red_moderador
    post "/red/moderacion/comunidades/#{c.token}/certificar"
    assert_equal "certificada", c.reload.estado
    m = c.membresias.find_by(user: ana)
    assert_equal %w[verificada administrador], [m.estado, m.rol]
  end

  test "membresías: se pide con evidencia, aprueba un verificador, nunca uno mismo" do
    admin, ana, beto = red_usuario("Admin"), red_usuario("Ana"), red_usuario("Beto")
    c = red_comunidad("Barrio Modelia", miembros: [])
    red_membresia(c, admin, rol: "administrador")

    sign_in ana
    post "/red/comunidades/#{c.token}/unirse", params: { evidencia: "Apartamento 302, torre 4" }
    assert_equal "solicitada", c.membresias.find_by(user: ana).estado

    sign_in beto # no es verificador: para él la gestión no existe
    post "/red/comunidades/#{c.token}/gestion/#{ana.red_perfil.token}/aprobar"
    assert_response :not_found
    get "/red/comunidades/#{c.token}/gestion"
    assert_response :not_found

    sign_in admin
    get "/red/comunidades/#{c.token}/gestion"
    assert_response :ok
    assert_includes response.body, "Apartamento 302"
    post "/red/comunidades/#{c.token}/gestion/#{ana.red_perfil.token}/aprobar"
    m = c.membresias.find_by(user: ana)
    assert_equal "verificada", m.estado
    assert_equal admin.id, m.verificada_por_id
    assert m.vence_el > 11.months.from_now.to_date

    # Ana, ya verificadora, no puede tocar su propia membresía.
    m.update!(rol: "verificador")
    sign_in ana
    post "/red/comunidades/#{c.token}/gestion/#{ana.red_perfil.token}/renovar"
    assert_match "propia", flash[:alert]
    # Ni actuar como administradora.
    post "/red/comunidades/#{c.token}/gestion/#{admin.red_perfil.token}/revocar", params: { motivo: "x" }
    assert_response :not_found

    sign_in admin
    post "/red/comunidades/#{c.token}/gestion/#{ana.red_perfil.token}/revocar"
    assert_match "motivo", flash[:alert]
    post "/red/comunidades/#{c.token}/gestion/#{ana.red_perfil.token}/revocar", params: { motivo: "Se mudó" }
    assert_equal "revocada", m.reload.estado
  end

  test "correo institucional: el dominio es condición para pedir entrar" do
    c = red_comunidad("Universidad Nacional", metodo_verificacion: "correo_institucional", dominio_correo: "unal.edu.co")
    ana = red_usuario("Ana")
    sign_in ana
    post "/red/comunidades/#{c.token}/unirse", params: { evidencia: "Estudiante" }
    assert_nil c.membresias.find_by(user: ana)
    ana.update!(email: "ana@unal.edu.co")
    post "/red/comunidades/#{c.token}/unirse", params: { evidencia: "Estudiante" }
    assert_equal "solicitada", c.membresias.find_by(user: ana).estado
  end

  test "el directorio de miembros solo lo ven sus miembros verificados" do
    ana, beto = red_usuario("Ana"), red_usuario("Beto")
    c = red_comunidad(miembros: [ana])
    sign_in beto
    get "/red/comunidades/#{c.token}/miembros"
    assert_response :not_found
    sign_in ana
    get "/red/comunidades/#{c.token}/miembros"
    assert_response :ok
    assert_includes response.body, "Ana"
  end

  test "la comunidad no puede quedarse sin administradores" do
    admin, otro = red_usuario("Admin"), red_usuario("Otro")
    c = red_comunidad(miembros: [])
    m = red_membresia(c, admin, rol: "administrador")
    red_membresia(c, otro, rol: "administrador")
    sign_in otro
    post "/red/comunidades/#{c.token}/gestion/#{admin.red_perfil.token}/hacer_miembro"
    assert_equal "miembro", m.reload.rol
    post "/red/comunidades/#{c.token}/gestion/#{admin.red_perfil.token}/hacer_verificador"
    assert_equal "verificador", m.reload.rol
  end

  test "certificar una logia sincroniza sus miembros activos con su antigüedad" do
    logia = Logia.create!(nombre: "Logia Luz", slug: "luz-#{SecureRandom.hex(3)}", codigo: "LZ#{rand(10_000)}")
    u1 = User.create!(nombre: "Uno", apellido: "L", email: "u1_#{SecureRandom.hex(3)}@x.co", password: "password123", logia: logia)
    u2 = User.create!(nombre: "Dos", apellido: "L", email: "u2_#{SecureRandom.hex(3)}@x.co", password: "password123", logia: logia)
    Miembro.create!(user: u1, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(5), fecha_ingreso: Date.new(2015, 3, 1))
    mi2 = Miembro.create!(user: u2, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(5), fecha_ingreso: Date.new(2020, 1, 1))
    mod = red_moderador
    sign_in mod
    post "/red/moderacion/logias/#{logia.id}/certificar"
    c = Red::Comunidad.find_by(logia: logia)
    assert_equal ["certificada", "registro_oficial", 2], [c.estado, c.metodo_verificacion, c.miembros_count]
    assert_equal Date.new(2015, 3, 1), c.membresias.find_by(user: u1).verificada_at.to_date

    mi2.update_columns(estado: Miembro.estados.fetch("quite"))
    Red::CertificarLogia.call(logia, por: mod)
    assert_equal 1, c.reload.miembros_count
  end

  test "exportar CSV: solo administradores y sin correos ni otras comunidades" do
    admin, ana = red_usuario("Admin"), red_usuario("Ana")
    c = red_comunidad("Club Uno", miembros: [ana])
    red_comunidad("Comunidad Secreta", miembros: [ana])
    red_membresia(c, admin, rol: "administrador")
    sign_in ana
    get "/red/comunidades/#{c.token}/gestion/miembros.csv"
    assert_response :not_found
    sign_in admin
    get "/red/comunidades/#{c.token}/gestion/miembros.csv"
    assert_response :ok
    assert_includes response.body, "Ana"
    assert_not_includes response.body, "Secreta"
    assert_not_includes response.body, "@"

    ana.red_perfil.update_column(:nombre_publico, "=HYPERLINK(\"http://x.co\")")
    get "/red/comunidades/#{c.token}/gestion/miembros.csv"
    nombres = CSV.parse(response.body, headers: true).map { _1["Nombre en la red"] }
    assert nombres.all? { _1.start_with?("'") || _1.match?(/\A[[:alnum:]]/) }, "una fórmula sale como texto"
  end

  test "las pantallas de moderación abren para la plataforma y no existen para los demás" do
    c = red_comunidad("Pendiente", estado: "solicitada", solicitada_por: red_usuario("Pide"))
    pub = red_publicacion(red_usuario("Autor"), estado: "en_revision", motivo_revision: "Palabras de estafa")
    Red::Reporte.create!(objeto: pub, huella: "h1", motivo: "estafa")
    sign_in red_usuario("Curioso")
    get "/red/moderacion"
    assert_response :not_found
    sign_in red_moderador
    get "/red/moderacion"
    assert_response :ok
    assert_includes response.body, c.nombre
    assert_includes response.body, pub.titulo
    get "/red/moderacion/metricas"
    assert_response :ok
  end
end
