require "test_helper"

# DENUNCIAPP con el login de COMUNIA: el muro es público, denuncian los miembros activos con su sesión,
# la denuncia queda ligada a su usuario y en el muro no se dice quién fue.
class Denuncias::ApiTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  setup do
    preparar_denuncias
    @ana = vecino("Ana")
  end
  teardown { limpiar_denuncias }

  def operador = vecino("Operador", rol: "super_admin")

  def custodia_valida?(id) = Denuncias::Custodia.verificar(Denuncias::EventoCustodia.where(reporte_id: id).order(:n).to_a)[:valida]

  test "un miembro activo publica: sin EXIF en la copia pública, original cifrado, custodia y su usuario" do
    sign_in @ana
    r = publicar
    assert_redirected_to "/denuncias/mias"
    assert_equal [@ana, true, "publicado"], [r.user, r.verificada, r.estado]

    get "/denuncias"
    assert_response :success
    assert_includes response.body, "Robo en la esquina"
    foto = response.body[%r{/denuncias/fotos/[0-9a-f-]+\.jpg}]
    get foto
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_not contiene(response.body, "GPS")

    ev = Denuncias::Evidencia.find_by!(reporte_id: r.id)
    assert_not contiene(File.binread(File.join(@dir_evidencia, ev.clave_original)), "GPS") # cifrado
    assert_equal Denuncias::Cripto.sha256_hex(DenunciasPrueba.jpeg_con_exif), ev.sha256_original
    assert_equal({ valida: true, eventos: 2 }, Denuncias::Custodia.verificar(r.eventos.to_a))
  end

  test "el muro es público y no muestra quién publicó; solo el sello" do
    sign_in @ana
    publicar
    sign_out @ana

    get "/denuncias"
    assert_response :success
    assert_includes response.body, "Robo en la esquina"
    assert_includes response.body, "Miembro de una comunidad certificada"
    assert_not_includes response.body, "Ana Prueba"
    assert_not_includes response.body, @ana.email
  end

  test "el muro es uno solo: desde dentro de una comunidad se va a /denuncias, sin el prefijo" do
    sign_in @ana
    slug = @ana.logia.slug
    get "/t/#{slug}/denuncias/nueva?recompensa=x"
    assert_redirected_to "/denuncias/nueva?recompensa=x"
  end

  test "sin sesión lleva a entrar; sin ficha activa no se denuncia" do
    get "/denuncias/nueva"
    assert_redirected_to "/login"
    assert_nil publicar
    assert_redirected_to "/login"

    sin_ficha = vecino("Iris", estado: :quite)
    sign_in sin_ficha
    get "/denuncias/nueva"
    assert_redirected_to "/denuncias"
    assert_nil publicar
    assert_equal 0, Denuncias::Reporte.count
  end

  test "rechaza una foto alterada en el camino y lo que no está en la lista blanca" do
    sign_in @ana
    assert_nil publicar({}, hashes: ["0" * 64])
    assert_response :unprocessable_content
    assert_empty Dir.glob(File.join(@dir_evidencia, "**/*")).select { File.file?(_1) }

    assert_nil publicar(categoria: "x'; DROP TABLE denuncias_reportes;--")
    assert_nil publicar(localidad: "Medellín")
    assert_nil publicar(acepto_terminos: "no")
    assert_equal 0, Denuncias::Reporte.count
  end

  test "ubicación de buscado exige una recompensa oficial publicada" do
    sign_in @ana
    assert_nil publicar(categoria: "ubicacion_buscado")
    Denuncias::Recompensa.create!(id: "rec-1", titulo: "Buscado X", entidad: "Policía", monto_texto: "$10 millones",
                                  fuente_url: "https://policia.gov.co", estado: "publicada", creado_en: Time.utc(2026, 10, 19))
    get "/denuncias/nueva", params: { recompensa: "rec-1" }
    assert_includes response.body, "Buscado X"
    assert publicar(categoria: "ubicacion_buscado", recompensa_id: "rec-1")
  end

  test "limita a 5 denuncias por hora por persona" do
    sign_in @ana
    5.times { assert publicar }
    assert_nil publicar
    assert_response :too_many_requests

    sign_in vecino("Bea")
    assert publicar
  end

  test "«Mis denuncias»: cada quien ve y retira solo lo suyo" do
    sign_in @ana
    mia = publicar
    sign_in vecino("Bea")
    ajena = publicar(titulo: "Otra cosa")

    get "/denuncias/mias"
    assert_includes response.body, "Otra cosa"
    assert_not_includes response.body, "Robo en la esquina"
    post "/denuncias/#{mia.id}/retirar"
    assert_equal "publicado", mia.reload.estado

    sign_in @ana
    foto = "/denuncias/fotos/#{File.basename(mia.evidencias.first.clave_publica)}"
    post "/denuncias/#{mia.id}/retirar"
    assert_redirected_to "/denuncias/mias"
    assert_equal "retirado", mia.reload.estado
    get foto
    assert_response :not_found
    assert_equal "retirado_por_autor", mia.eventos.reload.last.tipo
    assert custodia_valida?(mia.id)
    assert_equal "publicado", ajena.reload.estado
  end

  test "un tercero sin cuenta pide el retiro con captcha y el operador lo acepta" do
    sign_in @ana
    r = publicar
    sign_out @ana

    Denuncias::Captcha.verificador = ->(_) { false }
    post "/denuncias/#{r.id}/retiro", params: { motivo: "Esa persona soy yo y es falso" }
    assert_response :unprocessable_content
    Denuncias::Captcha.verificador = ->(_) { true }
    get "/denuncias/#{r.id}/retiro"
    assert_response :success
    post "/denuncias/#{r.id}/retiro", params: { motivo: "Esa persona soy yo y es falso", contacto: "yo@correo.co" }
    assert_redirected_to "/denuncias"
    solicitud = Denuncias::SolicitudRetiro.pendientes.sole
    assert_not_includes solicitud.contacto_cif, "correo"

    sign_in operador
    get "/denuncias/admin"
    assert_response :success
    assert_includes response.body, "yo@correo.co"
    assert_includes response.body, "Ana Prueba · #{@ana.email}", "el operador sí ve quién publicó"

    con_proteccion_csrf do
      post "/denuncias/admin/retiros/#{solicitud.id}/aceptar"
      assert_response :unprocessable_content
    end
    post "/denuncias/admin/retiros/#{solicitud.id}/aceptar"
    assert_response :redirect
    assert_equal "retirado", r.reload.estado
    assert custodia_valida?(r.id)
  end

  test "con 5 solicitudes de personas distintas se oculta; una misma no cuenta dos veces" do
    sign_in @ana
    r = publicar
    sign_out @ana
    pedir = lambda do |ip|
      post "/denuncias/#{r.id}/retiro", params: { motivo: "Esto es falso y me perjudica" }, env: { "REMOTE_ADDR" => ip }
    end
    pedir.("1.1.1.1")
    pedir.("1.1.1.1")
    assert_equal 1, Denuncias::SolicitudRetiro.pendientes.count
    %w[2.2.2.2 3.3.3.3 4.4.4.4].each { pedir.(_1) }
    assert_equal "publicado", r.reload.estado
    pedir.("5.5.5.5")
    assert_equal "oculto", r.reload.estado
    get "/denuncias"
    assert_not_includes response.body, "Robo en la esquina"
    get "/denuncias/#{r.id}/retiro"
    assert_response :not_found

    sign_in operador
    post "/denuncias/admin/reportes/#{r.id}/restaurar"
    assert_response :redirect
    assert_equal "publicado", r.reload.estado
    assert_equal 0, Denuncias::SolicitudRetiro.pendientes.where(reporte_id: r.id).count
    assert custodia_valida?(r.id)
  end

  test "las cédulas y teléfonos no salen al muro, pero el original queda cifrado" do
    sign_in @ana
    r = publicar(descripcion: "El dueño es CC 79.123.456, tel 3105551234")
    get "/denuncias"
    assert_includes response.body, "El dueño es CC [dato oculto], tel [dato oculto]"
    assert_not_includes response.body, "79.123.456"
    assert r.texto_original_cif.present?
    assert_not_includes r.texto_original_cif, "79.123.456"
    assert_includes r.eventos.pluck(:tipo), "datos_ocultados"
  end

  test "el muro y el panel escapan el HTML que manda quien denuncia" do
    sign_in @ana
    publicar(titulo: "<script>alert(1)</script>")
    get "/denuncias"
    assert_not_includes response.body, "<script>alert(1)</script>"
    sign_in operador
    get "/denuncias/admin"
    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;"
  end

  test "el panel es solo del superadmin: ni un admin de comunidad ni un miembro entran" do
    [vecino("Alba", rol: "admin_logia"), @ana].each do |u|
      sign_in u
      get "/denuncias/admin"
      assert_response :redirect
    end
  end

  test "el paquete para la autoridad: PDF con hashes y custodia, registrado, sin cédulas en claro" do
    sign_in @ana
    reporte = publicar(descripcion: "El dueño, CC 79.123.456, lo deja ahí siempre.")
    pdf, sha = Denuncias::Paquete.generar(reporte, "Secretaría de Movilidad")
    assert pdf.start_with?("%PDF-")
    remision = Denuncias::Remision.find_by!(reporte_id: reporte.id)
    assert_equal ["Secretaría de Movilidad", Denuncias::Cripto.sha256_hex(pdf), sha],
                 [remision.entidad, remision.paquete_sha256, remision.paquete_sha256]
    eventos = reporte.eventos.reload.to_a
    assert_equal "paquete_generado", eventos.last.tipo
    assert Denuncias::Custodia.verificar(eventos)[:valida]
    assert_not contiene(pdf, "79.123.456")

    sign_in operador
    post "/denuncias/admin/reportes/#{reporte.id}/paquete", params: { entidad: "" }
    assert_response :bad_request
    post "/denuncias/admin/reportes/#{reporte.id}/paquete", params: { entidad: "Policía Nacional" }
    assert_response :success
    assert_equal "application/pdf", response.media_type
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
