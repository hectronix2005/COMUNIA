require "test_helper"

# Fase 7: mensajería intermediada, contacto sin cuenta, reseñas verificables, reportes y avisos.
class Red::MensajeriaTest < ActionDispatch::IntegrationTest
  include RedPrueba

  setup do
    Red::Captcha.verificador = ->(t) { t == "ok" }
    @ana = red_usuario("Ana", contacto_telefono: "3001234567", contacto_correo: "ana@privado.co")
    @beto = red_usuario("Beto", contacto_telefono: "3109876543")
    @club = red_comunidad("Club Uno", miembros: [@ana, @beto])
    @pub = red_publicacion(@ana)
  end

  teardown { Red::Captcha.verificador = nil }

  def escribir_a(perfil, cuerpo = "Hola, me interesa", **extra)
    post "/red/p/#{perfil.token}/escribir", params: { cuerpo: cuerpo }.merge(extra)
  end

  test "conversación intermediada: nadie ve teléfono ni correo hasta que se comparte" do
    sign_in @beto
    escribir_a(@ana.red_perfil, publicacion: @pub.token)
    c = Red::Conversacion.last
    assert_redirected_to "/red/conversaciones/#{c.token}"
    assert_equal [@beto.id, @ana.id, @pub.id], [c.iniciador_id, c.destinatario_id, c.publicacion_id]
    assert_equal 1, @ana.notificaciones.where(tipo: "red_mensaje").count

    sign_in @ana
    get "/red/conversaciones/#{c.token}"
    assert_response :ok
    assert_includes response.body, "Hola, me interesa"
    assert_not_includes response.body, "3109876543"
    assert c.mensajes.first.reload.leido_at, "al abrirla se marca leída"

    sign_in @beto
    get "/red/conversaciones/#{c.token}"
    assert_not_includes response.body, "3001234567"
    assert_not_includes response.body, "ana@privado.co"

    sign_in @ana
    post "/red/conversaciones/#{c.token}/compartir"
    sign_in @beto
    get "/red/conversaciones/#{c.token}"
    assert_includes response.body, "3001234567"
    assert_includes response.body, "ana@privado.co"
  end

  test "un tercero no ve la conversación y recibe lo mismo que con un token inventado" do
    sign_in @beto
    escribir_a(@ana.red_perfil)
    follow_redirect!
    c = Red::Conversacion.last
    sign_in red_usuario("Curioso")
    get "/red/conversaciones/#{c.token}"
    real = sin_aleatorios(response.body)
    assert_response :not_found
    get "/red/conversaciones/#{'x' * 24}"
    assert_equal real, sin_aleatorios(response.body)
    post "/red/conversaciones/#{c.token}/mensajes", params: { cuerpo: "intruso" }
    assert_response :not_found
    assert_not c.mensajes.exists?(cuerpo: "intruso")
  end

  test "escribir a un perfil que no te es visible responde como si no existiera" do
    oculta = red_usuario("Oculta", alcance: "mis_comunidades")
    red_comunidad("Club Dos", miembros: [oculta])
    sign_in @beto
    escribir_a(oculta.red_perfil)
    a = sin_aleatorios(response.body)
    assert_response :not_found
    post "/red/p/#{'y' * 24}/escribir", params: { cuerpo: "Hola" }
    assert_equal a, sin_aleatorios(response.body)
    assert_equal 0, Red::Conversacion.count
  end

  test "a quien tiene el perfil solo para su comunidad se le escribe desde su publicación pública" do
    reservada = red_usuario("Reservada", alcance: "mis_comunidades")
    red_comunidad("Club Tres", miembros: [reservada])
    pub = red_publicacion(reservada, titulo: "Vendo bicicleta usada")
    sign_in @beto
    escribir_a(reservada.red_perfil)
    assert_response :not_found, "sin publicación, su perfil no existe para Beto"
    escribir_a(reservada.red_perfil, publicacion: pub.token)
    assert_equal pub.id, Red::Conversacion.last&.publicacion_id
    privada = red_publicacion(reservada, titulo: "Solo para el club tres", alcance: "mis_comunidades")
    escribir_a(reservada.red_perfil, "Otra", publicacion: privada.token)
    assert_response :not_found
  end

  test "la publicación ligada debe ser visible y del destinatario" do
    otra = red_publicacion(@beto, titulo: "De Beto, no de Ana")
    sign_in red_usuario("Carla").tap { red_membresia(@club, _1) }
    escribir_a(@ana.red_perfil, publicacion: otra.token)
    assert_nil Red::Conversacion.last.publicacion_id
  end

  test "bloquear corta la conversación y que vuelva a escribir" do
    sign_in @beto
    escribir_a(@ana.red_perfil)
    c = Red::Conversacion.last
    sign_in @ana
    post "/red/conversaciones/#{c.token}/bloquear"
    assert_equal "bloqueada", c.reload.estado
    sign_in @beto
    post "/red/conversaciones/#{c.token}/mensajes", params: { cuerpo: "¿Sigues ahí?" }
    assert_match "cerrada", flash[:alert]
    escribir_a(@ana.red_perfil, "Abro otra", publicacion: @pub.token)
    assert_match "No puedes escribir", flash[:alert]
    assert_equal 1, Red::Conversacion.count
  end

  test "no puedes escribirte a ti mismo" do
    sign_in @ana
    escribir_a(@ana.red_perfil)
    assert_equal 0, Red::Conversacion.count
  end

  test "límite diario de conversaciones nuevas, más corto en cuarentena" do
    nuevo = red_usuario("Nuevo", cuarentena_hasta: 2.days.from_now)
    red_membresia(@club, nuevo)
    destinos = Array.new(6) { |i| red_usuario("Destino #{i}").tap { red_membresia(@club, _1) } }
    sign_in nuevo
    destinos.each { escribir_a(_1.red_perfil) }
    assert_equal Red::ConversacionesController::NUEVAS_POR_DIA_CUARENTENA, Red::Conversacion.count
    assert_match "muchas conversaciones", flash[:alert]
  end

  test "reseña verificable: solo tras una conversación real con los dos y un día de margen" do
    sign_in @beto
    escribir_a(@ana.red_perfil)
    c = Red::Conversacion.last
    post "/red/conversaciones/#{c.token}/resena", params: { puntaje: "5", comentario: "Excelente" }
    assert_match "Aún no", flash[:alert]

    c.mensajes.create!(user: @ana, cuerpo: "Claro, te cuento")
    c.mensajes.update_all(created_at: 2.days.ago)
    post "/red/conversaciones/#{c.token}/resena", params: { puntaje: "9" }
    assert_equal 0, Red::Resena.count
    post "/red/conversaciones/#{c.token}/resena", params: { puntaje: "5", comentario: "Excelente" }
    assert_equal 1, Red::Resena.where(autor: @beto, sujeto: @ana, puntaje: 5).count
    post "/red/conversaciones/#{c.token}/resena", params: { puntaje: "1" }
    assert_equal 1, Red::Resena.count, "una reseña por persona y conversación"
    get "/red/p/#{@ana.red_perfil.token}"
    assert_includes response.body, "1 reseñas"
  end

  test "contacto sin cuenta: captcha, consentimiento y medio válido; el autor no expone sus datos" do
    get "/red/publicaciones/#{@pub.token}/contactar"
    assert_response :ok
    assert_not_includes response.body, "3001234567"
    base = { nombre: "Visitante", contacto: "visita@correo.co", cuerpo: "¿Sigue disponible?", acepto: "1", "cf-turnstile-response" => "ok" }
    post "/red/publicaciones/#{@pub.token}/contactar", params: base.merge("cf-turnstile-response" => "malo")
    assert_response :unprocessable_content
    post "/red/publicaciones/#{@pub.token}/contactar", params: base.merge(acepto: "0")
    assert_response :unprocessable_content
    post "/red/publicaciones/#{@pub.token}/contactar", params: base.merge(contacto: "no-es-un-medio")
    assert_response :unprocessable_content
    post "/red/publicaciones/#{@pub.token}/contactar", params: base.merge(contacto: { "$ne" => "" })
    assert_response :unprocessable_content
    assert_equal 0, Red::Conversacion.count

    post "/red/publicaciones/#{@pub.token}/contactar", params: base
    assert_redirected_to "/red/publicaciones/#{@pub.token}"
    c = Red::Conversacion.last
    assert c.externa?
    assert_not_includes c.contacto_externo_cif, "visita@correo.co", "se guarda cifrado"

    sign_in @ana
    get "/red/conversaciones/#{c.token}"
    assert_includes response.body, "visita@correo.co"
    assert_includes response.body, "¿Sigue disponible?"
  end

  test "contacto sin cuenta a una publicación solo de la comunidad: no existe" do
    privada = red_publicacion(@ana, alcance: "mis_comunidades", titulo: "Solo para el club")
    get "/red/publicaciones/#{privada.token}/contactar"
    assert_response :not_found
    post "/red/publicaciones/#{privada.token}/contactar", params: { nombre: "X", contacto: "x@x.co", cuerpo: "hola hola", acepto: "1",
                                                                    "cf-turnstile-response" => "ok" }
    assert_response :not_found
  end

  test "reportes: uno por persona, a los 3 la publicación pasa a revisión y se avisa a moderación" do
    mod = red_moderador
    reportantes = Array.new(3) { |i| red_usuario("Rep #{i}") }
    reportantes.first(2).each do |r|
      sign_in r
      2.times { post "/red/reportar", params: { tipo: "publicacion", token: @pub.token, motivo: "estafa" } }
    end
    assert_equal 2, Red::Reporte.count, "el mismo usuario cuenta una vez"
    assert_equal "activa", @pub.reload.estado
    sign_in reportantes.last
    post "/red/reportar", params: { tipo: "publicacion", token: @pub.token, motivo: "estafa" }
    assert_equal "en_revision", @pub.reload.estado
    assert_equal 1, mod.notificaciones.where(tipo: "red_moderacion").count
    get "/red/publicaciones/#{@pub.token}"
    assert_response :not_found, "en revisión ya no se ve"
  end

  test "reportes sin cuenta: captcha y la misma respuesta exista o no lo reportado" do
    post "/red/reportar", params: { tipo: "publicacion", token: @pub.token, motivo: "spam" }
    assert_equal 0, Red::Reporte.count, "sin captcha no cuenta"
    post "/red/reportar", params: { tipo: "publicacion", token: @pub.token, motivo: "spam", "cf-turnstile-response" => "ok" }
    real = [response.status, flash[:notice]]
    assert_equal 1, Red::Reporte.count
    post "/red/reportar", params: { tipo: "publicacion", token: "no-existe", motivo: "spam", "cf-turnstile-response" => "ok" }
    assert_equal real, [response.status, flash[:notice]]
    post "/red/reportar", params: { tipo: "publicacion", token: @pub.token, motivo: "spam", "cf-turnstile-response" => "ok" }
    assert_equal 1, Red::Reporte.count, "la misma IP cuenta una vez"
    assert_not_includes Red::Reporte.last.huella, "127.0.0.1"
  end

  test "moderación: descartar devuelve la publicación, sancionar la retira y aprobar avisa; solo moderadores" do
    mod = red_moderador
    reportar = lambda do |pub, n|
      Array.new(n) { |i| red_usuario("Rep #{i}") }.each do |r|
        sign_in r
        post "/red/reportar", params: { tipo: "publicacion", token: pub.token, motivo: "estafa" }
      end
    end
    reportar.(@pub, 3)
    assert_equal "en_revision", @pub.reload.estado
    reporte = Red::Reporte.pendientes.first

    sign_in @beto
    post "/red/moderacion/reportes/#{reporte.id}/sancionar"
    assert_response :not_found, "para quien no modera, la moderación no existe"
    assert_equal "en_revision", @pub.reload.estado

    sign_in mod
    get "/red/moderacion"
    assert_response :success
    post "/red/moderacion/reportes/#{reporte.id}/descartar"
    assert_redirected_to "/red/moderacion"
    assert_equal "activa", @pub.reload.estado
    assert_equal 0, Red::Reporte.pendientes.count, "se resuelven todos los reportes de lo mismo"

    otra = red_publicacion(@ana, titulo: "Préstamos sin papeles")
    reportar.(otra, 1)
    sign_in mod
    post "/red/moderacion/reportes/#{Red::Reporte.pendientes.last.id}/sancionar"
    assert_equal "retirada", otra.reload.estado
    assert_equal 1, @ana.red_perfil.reload.sanciones

    retenida = red_publicacion(@ana, titulo: "Clases de guitarra", estado: "en_revision")
    post "/red/moderacion/publicaciones/#{retenida.token}/aprobar"
    assert_equal "activa", retenida.reload.estado
    assert @ana.notificaciones.where(tipo: "red_moderacion", titulo: "Tu publicación ya está visible").exists?
    post "/red/moderacion/publicaciones/#{retenida.token}/aprobar"
    assert_response :not_found, "solo se aprueba lo que está en revisión"
  end

  test "solo se reporta un mensaje de una conversación propia" do
    sign_in @beto
    escribir_a(@ana.red_perfil, "Mensaje ofensivo")
    m = Red::Mensaje.last
    sign_in red_usuario("Ajena")
    post "/red/reportar", params: { tipo: "mensaje", token: m.id.to_s, motivo: "ofensivo" }
    assert_equal 0, Red::Reporte.count
    sign_in @ana
    post "/red/reportar", params: { tipo: "mensaje", token: m.id.to_s, motivo: "ofensivo" }
    assert_equal 1, Red::Reporte.count
  end

  test "avisos: se listan y se marcan leídos; la campana cuenta los pendientes" do
    sign_in @beto
    escribir_a(@ana.red_perfil, "Te escribo")
    sign_in @ana
    get "/red/buscar"
    assert_includes response.body, "1 sin leer"
    get "/red/avisos"
    assert_response :ok
    assert_includes response.body, "Mensaje de Beto"
    assert_equal 0, @ana.notificaciones.no_leidas.count
  end
end
