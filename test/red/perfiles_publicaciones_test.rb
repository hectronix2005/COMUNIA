require "test_helper"

# Fase 4: perfiles (con hoja de vida y Ley 1581) y publicaciones necesito/ofrezco con alcance y antifraude.
class Red::PerfilesPublicacionesTest < ActionDispatch::IntegrationTest
  include RedPrueba

  def publicar(**extra)
    post "/red/publicaciones", params: { intencion: "ofrezco", categoria: "oficios", titulo: "Plomería a domicilio",
                                         descripcion: "Arreglo fugas, instalo grifería y calentadores.", modalidad: "presencial",
                                         alcance: "mis_comunidades" }.merge(extra)
  end

  test "bienvenida: sin consentimiento no hay perfil; con él queda la versión de la política y la primera foto" do
    u = red_usuario("Ana", perfil: false)
    sign_in u
    get "/red"
    assert_redirected_to "/red/bienvenida"
    post "/red/bienvenida", params: { nombre_publico: "Ana R.", alcance: "publico", visible_publico: "1" }
    assert_response :unprocessable_content
    assert_nil u.reload.red_perfil
    post "/red/bienvenida", params: { nombre_publico: "Ana R.", alcance: "publico", visible_publico: "1", acepto: "1" }
    assert_redirected_to "/red/comunidades"
    p = u.reload.red_perfil
    assert_equal Red::POLITICA_VERSION, p.politica_version
    assert p.visible_publico
    assert p.en_cuarentena?
    assert_equal 0, Red::Confianza.find_by(user_id: u.id).nivel
  end

  test "perfil: visible_publico solo vale con alcance público, y los campos con forma rara no entran" do
    u = red_usuario("Ana")
    sign_in u
    patch "/red/mi-perfil", params: { nombre_publico: "Ana", alcance: "mis_comunidades", visible_publico: "1", titular: { "x" => "y" } }
    assert_redirected_to "/red/mi-perfil"
    p = u.red_perfil.reload
    refute p.visible_publico
    assert_nil p.titular
    patch "/red/mi-perfil", params: { nombre_publico: "Ana", alcance: "inventado" }
    assert_equal "mis_comunidades", p.reload.alcance
  end

  test "perfil: elegir comunidades ajenas no las añade (ni da un error distinto)" do
    ana = red_usuario("Ana")
    mia = red_comunidad(miembros: [ana])
    ajena = red_comunidad(miembros: red_relleno(1))
    sign_in ana
    patch "/red/mi-perfil", params: { nombre_publico: "Ana", alcance: "elegidas", comunidades: [mia.id.to_s, ajena.id.to_s] }
    assert_redirected_to "/red/mi-perfil"
    assert_equal [mia.id], ana.red_perfil.reload.comunidad_ids_elegidas
  end

  test "hoja de vida: solo PDF, y se descarga solo si se puede ver el perfil" do
    ana = red_usuario("Ana")
    sign_in ana
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%prueba\n"), "application/pdf", original_filename: "cv.pdf")
    patch "/red/mi-perfil", params: { nombre_publico: "Ana", hoja_de_vida: pdf }
    assert ana.red_perfil.reload.hoja_de_vida.attached?
    texto = Rack::Test::UploadedFile.new(StringIO.new("hola"), "text/plain", original_filename: "cv.txt")
    patch "/red/mi-perfil", params: { nombre_publico: "Ana", hoja_de_vida: texto }
    assert_response :unprocessable_content
    token = ana.red_perfil.token
    get "/red/p/#{token}/hoja-de-vida"
    assert_response :success
    assert_equal "application/pdf", response.media_type
    sign_out ana
    get "/red/p/#{token}/hoja-de-vida" # perfil de alcance «mis_comunidades»: sin cuenta no se ve
    assert_response :not_found
  end

  test "perfil público: oculto e inexistente dan la misma respuesta" do
    oculto = red_usuario("Oculto", alcance: "mis_comunidades")
    visible = red_usuario("Visible", alcance: "publico", visible_publico: true)
    get "/red/p/#{visible.red_perfil.token}"
    assert_response :success
    get "/red/p/#{oculto.red_perfil.token}"
    cuerpo_oculto = response.body
    assert_response :not_found
    get "/red/p/#{'x' * 24}"
    assert_response :not_found
    assert_equal sin_aleatorios(cuerpo_oculto), sin_aleatorios(response.body)
  end

  test "publicar exige estar verificado en alguna comunidad" do
    ana = red_usuario("Ana")
    sign_in ana
    get "/red/publicaciones/new"
    assert_match "al menos una comunidad", response.body
    publicar
    assert_response :unprocessable_content
    assert_equal 0, ana.red_publicaciones.count
  end

  test "publicar: alcance de comunidad, la ve un compañero y no un extraño" do
    ana, beto, extrano = red_usuario("Ana"), red_usuario("Beto"), red_usuario("Extraño")
    red_comunidad(miembros: [ana, beto])
    red_comunidad(miembros: [extrano])
    sign_in ana
    publicar
    pub = ana.red_publicaciones.last
    assert_redirected_to "/red/publicaciones/#{pub.token}"
    assert_equal "activa", pub.estado
    sign_in beto
    get "/red/publicaciones/#{pub.token}"
    assert_response :success
    assert_match "Plomería a domicilio", response.body
    sign_in extrano
    get "/red/publicaciones/#{pub.token}"
    assert_response :not_found
    sign_out extrano
    get "/red/publicaciones/#{pub.token}"
    assert_response :not_found
  end

  test "cuarentena: lo público de una cuenta nueva no sale sin cuenta, pero sus comunidades sí lo ven" do
    nueva = red_usuario("Nueva", cuarentena_hasta: 2.days.from_now)
    companera = red_usuario("Compañera")
    red_comunidad(miembros: [nueva, companera])
    sign_in nueva
    publicar(alcance: "publico")
    pub = nueva.red_publicaciones.last
    assert pub.publica_desde > 1.day.from_now
    sign_in companera
    get "/red/publicaciones/#{pub.token}"
    assert_response :success
    sign_out companera
    get "/red/publicaciones/#{pub.token}"
    assert_response :not_found
    travel 3.days do
      get "/red/publicaciones/#{pub.token}"
      assert_response :success
    end
  end

  test "antifraude: frases de estafa mandan a revisión y nadie más la ve" do
    ana, beto = red_usuario("Ana"), red_usuario("Beto")
    red_comunidad(miembros: [ana, beto])
    sign_in ana
    publicar(titulo: "Empleo desde casa", descripcion: "Gana mucho, solo pago anticipado de la inscripción por Western Union.")
    pub = ana.red_publicaciones.last
    assert_equal "en_revision", pub.estado
    get "/red/publicaciones/#{pub.token}"
    assert_response :success # su autora sí la ve
    sign_in beto
    get "/red/publicaciones/#{pub.token}"
    assert_response :not_found
  end

  test "antifraude: tope diario y de publicaciones activas" do
    ana = red_usuario("Ana")
    red_comunidad(miembros: [ana])
    sign_in ana
    3.times { |i| publicar(titulo: "Servicio número #{i}") }
    assert_equal 3, ana.red_publicaciones.count
    publicar(titulo: "Servicio número 4")
    assert_response :unprocessable_content
    assert_match "al día", response.body
    ana.red_publicaciones.update_all(created_at: 2.days.ago) # ya pasó el día
    2.times { |i| publicar(titulo: "Otro servicio #{i}") }
    assert_equal 5, ana.red_publicaciones.count
    publicar(titulo: "Uno de más")
    assert_match "publicaciones activas", response.body
    assert_equal 5, ana.red_publicaciones.count
  end

  test "editar, pausar, cerrar y renovar solo lo propio" do
    ana, beto = red_usuario("Ana"), red_usuario("Beto")
    red_comunidad(miembros: [ana, beto])
    pub = red_publicacion(ana, vence_el: 2.days.from_now.to_date)
    sign_in beto
    patch "/red/publicaciones/#{pub.token}", params: { titulo: "Robado por Beto" }
    assert_response :not_found
    post "/red/publicaciones/#{pub.token}/estado", params: { estado: "cerrada" }
    assert_response :not_found
    sign_in ana
    post "/red/publicaciones/#{pub.token}/estado", params: { estado: "pausada" }
    assert_equal "pausada", pub.reload.estado
    post "/red/publicaciones/#{pub.token}/estado", params: { estado: "retirada" }
    assert_equal "pausada", pub.reload.estado
    post "/red/publicaciones/#{pub.token}/renovar"
    assert_equal 30.days.from_now.to_date, pub.reload.vence_el
    patch "/red/publicaciones/#{pub.token}", params: { titulo: "Arreglo de neveras y hornos" }
    assert_equal "Arreglo de neveras y hornos", pub.reload.titulo
    get "/red/mis-publicaciones"
    assert_match "Arreglo de neveras y hornos", response.body
  end

  test "Ley 1581: exportar trae lo mío y nada de las comunidades de otros; borrar lo quita todo" do
    ana, beto = red_usuario("Ana"), red_usuario("Beto")
    club = red_comunidad("Club Mío", miembros: [ana, beto])
    red_comunidad("Club Secreto de Beto", miembros: [beto])
    red_publicacion(ana)
    sign_in ana
    get "/red/mi-perfil/datos"
    assert_response :success
    datos = JSON.parse(response.body)
    assert_equal ["Club Mío"], datos["comunidades"].map { _1["comunidad"] }
    refute_includes response.body, "Club Secreto de Beto"
    assert_equal 1, datos["publicaciones"].size

    delete "/red/mi-perfil", params: { confirmacion: "no" }
    assert_response :unprocessable_content
    delete "/red/mi-perfil", params: { confirmacion: "BORRAR" }
    assert_redirected_to "/red"
    refute User.exists?(ana.id)
    assert_equal 0, Red::Publicacion.where(user_id: ana.id).count
    assert_equal 0, Red::Membresia.where(user_id: ana.id).count
    assert_equal 1, club.reload.miembros_count
  end

  test "las pantallas de perfil y publicación se pintan" do
    ana = red_usuario("Ana", alcance: "publico", visible_publico: true)
    red_comunidad(miembros: [ana])
    pub = red_publicacion(ana)
    sign_in ana
    %w[/red/bienvenida /red/mi-perfil /red/publicaciones/new /red/mis-publicaciones].each do |ruta|
      get ruta
      assert_includes [200, 302], response.status, ruta
    end
    get "/red/publicaciones/#{pub.token}/edit"
    assert_response :success
    sign_out ana
    get "/red/p/#{ana.red_perfil.token}"
    assert_response :success
    assert_match "Arreglo de neveras", response.body
  end
end
