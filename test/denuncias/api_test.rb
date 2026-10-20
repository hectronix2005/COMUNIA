require "test_helper"

# Traspaso, sección 5, pruebas 1–12 (tests/api.test.ts de DENUNCIAPP).
class Denuncias::ApiTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  setup { preparar_denuncias }
  teardown { limpiar_denuncias }

  def operador
    rol = Rol.find_by(codigo: "super_admin") || Rol.create!(nombre: "Super #{SecureRandom.hex(3)}", codigo: "super_admin")
    logia = Logia.create!(nombre: "L", slug: "l-#{SecureRandom.hex(4)}", codigo: "L#{rand(100_000)}")
    User.create!(nombre: "Op", apellido: "Erador", email: "op_#{SecureRandom.hex(4)}@test.com", password: "password123",
                 logia: logia, rol_ref: rol)
  end

  def en_comunia(usuario)
    host! "www.example.com"
    sign_in usuario, scope: :user
  end

  test "1. se publica en el muro, sin EXIF en la copia pública, con original cifrado y custodia válida" do
    r = publicar
    assert_equal 201, r.status
    cuerpo = JSON.parse(r.body)
    assert_match(/\A([0-9A-Z]{5}-){4}[0-9A-Z]{5}\z/, cuerpo["codigo"])

    lista = muro
    assert_equal 1, lista.size
    assert_equal [cuerpo["id"], "Robo en la esquina", "publicado"], lista[0].values_at("id", "titulo", "estado")
    assert_not lista[0].key?("codigo_hash")

    get lista[0]["fotos"][0]
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_not contiene(response.body, "GPS")

    ev = Denuncias::Evidencia.find_by!(reporte_id: cuerpo["id"])
    assert_not contiene(File.binread(File.join(@dir_evidencia, ev.clave_original)), "GPS") # cifrado
    assert ev.metadatos_cif.present?
    assert_equal Denuncias::Cripto.sha256_hex(DenunciasPrueba.jpeg_con_exif), ev.sha256_original
    assert_equal({ valida: true, eventos: 2 }, Denuncias::Custodia.verificar(Denuncias::EventoCustodia.where(reporte_id: cuerpo["id"]).order(:n).to_a))
  end

  test "2. no guarda la IP en ninguna parte" do
    ip = "203.0.113.77"
    log_antes = File.size?(Rails.root.join("log/test.log")).to_i
    publicar({}, ip: ip)
    assert_response :created

    volcado = %w[reportes evidencias eventos_custodia solicitudes_retiro cuentas remisiones pases_usados recompensas].map do |t|
      ActiveRecord::Base.connection.select_all("SELECT * FROM denuncias_#{t}").to_a
    end.to_json
    assert_not_includes volcado, ip
    archivos = Dir.glob(File.join(@dir_evidencia, "**/*")).select { File.file?(_1) }
    assert_equal 2, archivos.size
    archivos.each { assert_not contiene(File.binread(_1), ip) }
    # Tampoco en el log de Rails: en el host del módulo no se escribe nada.
    log = File.binread(Rails.root.join("log/test.log")).byteslice(log_antes..).to_s
    assert_not contiene(log, ip)
    assert_not contiene(log, "/api/reportes")
  end

  test "3. rechaza una foto cuyo hash no coincide (alterada en el camino)" do
    assert_equal 400, publicar({}, hashes: ["0" * 64]).status
    assert_equal 0, Denuncias::Reporte.count
    assert_empty Dir.glob(File.join(@dir_evidencia, "**/*")).select { File.file?(_1) }
  end

  test "4. rechaza categorías y localidades fuera de la lista blanca" do
    assert_equal 400, publicar(categoria: "x'; DROP TABLE denuncias_reportes;--").status
    assert_equal 400, publicar(localidad: "Medellín").status
    assert Denuncias::Reporte.table_exists?
  end

  test "5. exige captcha y aceptar términos" do
    Denuncias::Captcha.verificador = ->(_) { false }
    assert_equal 400, publicar.status
    Denuncias::Captcha.verificador = ->(_) { true }
    assert_equal 400, publicar(acepto_terminos: "no").status
  end

  test "6. ubicación de buscado exige una recompensa oficial publicada" do
    assert_equal 400, publicar(categoria: "ubicacion_buscado").status
    Denuncias::Recompensa.create!(id: "rec-1", titulo: "Buscado X", entidad: "Policía", monto_texto: "$10 millones",
                                  fuente_url: "https://policia.gov.co", estado: "publicada", creado_en: Time.utc(2026, 10, 19))
    assert_equal 201, publicar(categoria: "ubicacion_buscado", recompensa_id: "rec-1").status
  end

  test "7. limita a 5 denuncias por hora por IP" do
    5.times { assert_equal 201, publicar.status }
    assert_equal 429, publicar.status
    assert_equal 201, publicar({}, ip: "8.8.8.8").status
  end

  test "8. el autor retira con su código: desaparece del muro y se borra la copia pública" do
    cuerpo = JSON.parse(publicar.body)
    foto = muro[0]["fotos"][0]
    post "/api/seguimiento", params: { codigo: cuerpo["codigo"].downcase, accion: "retirar" }, as: :json
    assert_equal({ "id" => cuerpo["id"], "estado" => "retirado" }, JSON.parse(response.body))
    assert_empty muro
    get foto
    assert_response :not_found
    assert_equal "retirado_por_autor", Denuncias::EventoCustodia.where(reporte_id: cuerpo["id"]).order(:n).last.tipo
  end

  test "9. un tercero pide retiro y el operador lo acepta desde el panel" do
    id = JSON.parse(publicar.body)["id"]
    post "/api/reportes/#{id}/retiro", params: { motivo: "Esa persona soy yo y es falso", contacto: "yo@correo.co" }, as: :json
    assert_response :created
    solicitud = Denuncias::SolicitudRetiro.pendientes.sole
    assert_not_includes solicitud.contacto_cif, "correo"

    en_comunia(operador)
    get "/denuncias/admin"
    assert_response :success
    assert_includes response.body, "yo@correo.co"

    # Sin token CSRF el panel no acepta nada (en DENUNCIAPP: sin Origin, 403).
    con_proteccion_csrf do
      post "/denuncias/admin/retiros/#{solicitud.id}/aceptar"
      assert_response :unprocessable_content
    end
    post "/denuncias/admin/retiros/#{solicitud.id}/aceptar"
    assert_response :redirect
    assert_equal "retirado", Denuncias::Reporte.find(id).estado
    assert Denuncias::Custodia.verificar(Denuncias::EventoCustodia.where(reporte_id: id).order(:n).to_a)[:valida]
  end

  test "10. con 5 solicitudes de IPs distintas se oculta; una misma IP no cuenta dos veces" do
    id = JSON.parse(publicar.body)["id"]
    pedir = ->(ip) { post("/api/reportes/#{id}/retiro", params: { motivo: "Esto es falso y me perjudica" }, as: :json, env: { "REMOTE_ADDR" => ip }); response.status }
    assert_equal 201, pedir.("1.1.1.1")
    assert_equal 429, pedir.("1.1.1.1")
    %w[2.2.2.2 3.3.3.3 4.4.4.4].each { assert_equal 201, pedir.(_1) }
    assert_equal "publicado", Denuncias::Reporte.find(id).estado
    assert_equal 201, pedir.("5.5.5.5")
    assert_equal "oculto", Denuncias::Reporte.find(id).estado
    assert_empty muro

    en_comunia(operador)
    post "/denuncias/admin/reportes/#{id}/restaurar"
    assert_response :redirect
    assert_equal "publicado", Denuncias::Reporte.find(id).estado
    assert_equal 0, Denuncias::SolicitudRetiro.pendientes.where(reporte_id: id).count
    assert Denuncias::Custodia.verificar(Denuncias::EventoCustodia.where(reporte_id: id).order(:n).to_a)[:valida]
  end

  test "11. las cédulas y teléfonos no salen al muro, pero el original queda cifrado" do
    id = JSON.parse(publicar(descripcion: "El dueño es CC 79.123.456, tel 3105551234").body)["id"]
    assert_equal "El dueño es CC [dato oculto], tel [dato oculto]", muro[0]["descripcion"]
    fila = Denuncias::Reporte.find(id)
    assert fila.texto_original_cif.present?
    assert_not_includes fila.texto_original_cif, "79.123.456"
    assert_includes Denuncias::EventoCustodia.where(reporte_id: id).pluck(:tipo), "datos_ocultados"
  end

  test "12. el panel escapa el HTML que manda el ciudadano" do
    publicar(titulo: "<script>alert(1)</script>")
    en_comunia(operador)
    get "/denuncias/admin"
    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;"
  end

  test "el panel es solo del superadmin: un admin de logia no entra" do
    rol = Rol.find_by(codigo: "admin") || Rol.create!(nombre: "Admin #{SecureRandom.hex(3)}", codigo: "admin")
    logia = Logia.create!(nombre: "L", slug: "l-#{SecureRandom.hex(4)}", codigo: "L#{rand(100_000)}")
    admin = User.create!(nombre: "A", apellido: "L", email: "al_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: logia, rol_ref: rol)
    en_comunia(admin)
    get "/denuncias/admin"
    assert_response :redirect
  end

  test "en el host del módulo no existe nada de COMUNIA, y el módulo no existe en el host de COMUNIA" do
    host! HOST
    %w[/login /dashboard /miembros /denuncias/admin /pases/claves.json /up].each do |ruta|
      get ruta
      assert_response :not_found, ruta
    end
    get "/"
    assert_response :success
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_nil response.headers["Set-Cookie"].to_s[/_gran_logia_de_colombia_session=[^;]+;[^\n]*domain/i]

    host! "www.example.com"
    get "/api/reportes"
    assert_response :not_found
  end

  test "el muro sirve sus scripts aunque Rails proteja el JavaScript, y solo los de la lista" do
    host! HOST
    con_proteccion_csrf do
      get "/estaticos/pase.js"
      assert_response :success
      assert_match %r{\Atext/javascript}, response.media_type
      get "/estaticos/otro.js"
      assert_response :not_found
    end
  end

  private

  def con_proteccion_csrf
    antes = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = antes
  end
end
