require "test_helper"

# Traspaso, sección 5, pruebas 13–18 (tests/cuentas.test.ts de DENUNCIAPP).
class Denuncias::CuentasTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  setup do
    preparar_denuncias
    ActionMailer::Base.deliveries.clear
  end
  teardown { limpiar_denuncias }

  # Pide el enlace, lo abre y devuelve con la sesión de esa cuenta abierta (en esta sesión de prueba).
  def entrar(email)
    host! HOST
    post "/api/cuenta/enlace", params: { email: email, "cf-turnstile-response" => "ok" }
    assert_redirected_to "/entrar?enviado=1"
    correo = ActionMailer::Base.deliveries.last
    enlace = correo.body.to_s[%r{https?://\S+}]
    assert enlace, "el correo trae el enlace"
    get enlace
    assert_redirected_to "/cuenta"
    correo
  end

  def cookie_post(ruta, origen: ORIGEN, **opciones)
    post ruta, headers: { "Origin" => origen }, **opciones
    response
  end

  def otra_sesion = open_session.tap { _1.host! HOST }

  test "13. entra por correo, elige alias, publica con alias y retira lo suyo" do
    correo = entrar("Ciudadana@Correo.co")
    assert_equal ["ciudadana@correo.co"], correo.to
    assert_includes correo.body.to_s, "http://#{HOST}/cuenta/auth/magic_link"

    get "/api/cuenta"
    assert_equal({ "sesion" => true, "alias" => nil }, JSON.parse(response.body))
    assert_equal 200, cookie_post("/api/cuenta/alias", params: { alias: "vecina_suba" }, as: :json).status
    assert_equal 409, cookie_post("/api/cuenta/alias", params: { alias: "otro" }, as: :json).status # no se cambia

    assert_not_includes ActiveRecord::Base.connection.select_all("SELECT * FROM denuncias_cuentas").to_a.to_json, "correo.co"

    assert_equal 201, publicar(headers: { "Origin" => ORIGEN }, publicar_como: "alias", categoria: "mal_parqueo").status
    assert_equal 201, publicar(headers: { "Origin" => ORIGEN }, categoria: "mal_parqueo").status

    lista = muro
    assert_equal [nil, "vecina_suba"], lista.map { _1["alias"] }
    assert_not_includes lista.to_json, "cuenta_id"

    get "/api/cuenta/reportes"
    mias = JSON.parse(response.body)
    assert_equal 1, mias.size # la anónima no queda ligada a la cuenta
    assert_equal 200, cookie_post("/api/cuenta/reportes/#{mias[0]['id']}/retirar").status
    assert_equal "retirado", Denuncias::Reporte.find(mias[0]["id"]).estado
  end

  test "13b. el enlace sirve una sola vez" do
    entrar("una@correo.co")
    enlace = ActionMailer::Base.deliveries.last.body.to_s[%r{https?://\S+}]
    s = otra_sesion
    s.get enlace
    assert_equal "/cuenta/auth/fallo", URI(s.response.location).path
  end

  test "13c. la hora exacta del acceso se borra cuando ya no queda ningún enlace vivo" do
    vieja = Denuncias::Cuenta.buscar_o_crear("vieja@correo.co")
    vieja.update_columns(current_sign_in_at: 16.minutes.ago)
    entrar("nueva@correo.co")
    assert_nil vieja.reload.current_sign_in_at
    assert Denuncias::Cuenta.find_for_authentication(email: "nueva@correo.co").current_sign_in_at
  end

  test "14. sin sesión no se puede publicar con alias ni retirar lo ajeno" do
    ajena = otra_sesion
    ajena.post "/api/reportes", params: formulario({ publicar_como: "alias" })
    assert_equal 400, ajena.response.status

    entrar("a@correo.co")
    cookie_post("/api/cuenta/alias", params: { alias: "autora" }, as: :json)
    id = JSON.parse(publicar(headers: { "Origin" => ORIGEN }, publicar_como: "alias").body)["id"]

    otra = open_session
    otra.host! HOST
    otra.post "/api/cuenta/enlace", params: { email: "b@correo.co" }
    otra.get ActionMailer::Base.deliveries.last.body.to_s[%r{https?://\S+}]
    otra.post "/api/cuenta/reportes/#{id}/retirar", headers: { "Origin" => ORIGEN }
    assert_equal 404, otra.response.status
    # Desde otro sitio (Origin distinto) tampoco, aunque lleve la cookie.
    assert_equal 401, cookie_post("/api/cuenta/reportes/#{id}/retirar", origen: "https://malo.example").status
  end

  test "15. rechaza alias reservados o con formato inválido" do
    entrar("c@correo.co")
    ["admin", "AB", "con espacio", "<b>x</b>"].each do |a|
      assert_equal 400, cookie_post("/api/cuenta/alias", params: { alias: a }, as: :json).status, a
    end
  end

  test "16. pedir el enlace exige captcha" do
    Denuncias::Captcha.verificador = ->(_) { false }
    host! HOST
    post "/api/cuenta/enlace", params: { email: "x@correo.co" }
    assert_redirected_to "/entrar?error=captcha"
    assert_empty ActionMailer::Base.deliveries
    assert_equal 0, Denuncias::Cuenta.count
  end

  test "17. genera un PDF con hashes y custodia, y lo registra" do
    id = JSON.parse(publicar(descripcion: "El dueño, CC 79.123.456, lo deja ahí siempre.").body)["id"]
    reporte = Denuncias::Reporte.find(id)
    pdf, sha = Denuncias::Paquete.generar(reporte, "Secretaría de Movilidad")
    assert pdf.start_with?("%PDF-")
    remision = Denuncias::Remision.find_by!(reporte_id: id)
    assert_equal ["Secretaría de Movilidad", Denuncias::Cripto.sha256_hex(pdf)], [remision.entidad, remision.paquete_sha256]
    assert_equal sha, remision.paquete_sha256
    eventos = reporte.eventos.reload.to_a
    assert_equal "paquete_generado", eventos.last.tipo
    assert Denuncias::Custodia.verificar(eventos)[:valida]
    assert_not contiene(pdf, "79.123.456") # el texto del PDF va comprimido; no se busca en claro
  end

  test "18. exige la entidad destino" do
    id = JSON.parse(publicar.body)["id"]
    rol = Rol.find_by(codigo: "super_admin") || Rol.create!(nombre: "Super #{SecureRandom.hex(3)}", codigo: "super_admin")
    logia = Logia.create!(nombre: "L", slug: "l-#{SecureRandom.hex(4)}", codigo: "L#{rand(100_000)}")
    op = User.create!(nombre: "Op", apellido: "E", email: "op_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: logia, rol_ref: rol)
    host! "www.example.com"
    sign_in op, scope: :user
    post "/denuncias/admin/reportes/#{id}/paquete", params: { entidad: "" }
    assert_response :bad_request
    post "/denuncias/admin/reportes/#{id}/paquete", params: { entidad: "Policía Nacional" }
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
