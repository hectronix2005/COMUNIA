require "test_helper"

# Fase 6: ataques de extracción. Cada prueba intenta averiguar a qué OTRAS comunidades pertenece una
# persona (o cuántos miembros exactos suman) por la API, la búsqueda, el orden, los errores, las
# exportaciones o el número de consultas. Si alguna lo consigue, falla.
class Red::PrivacidadTest < ActionDispatch::IntegrationTest
  include RedPrueba

  setup do
    @pilar = red_usuario("Pilar", alcance: "publico", visible_publico: true, titular: "Electricista")
    @admin_a = red_usuario("Adela")
    @alfa = red_comunidad("Club Alfa", miembros: red_relleno(6))
    red_membresia(@alfa, @admin_a, rol: "administrador")
    red_membresia(@alfa, @pilar)
    @beta = red_comunidad("Universidad Beta", miembros: [@pilar] + red_relleno(10))
    @gamma = red_comunidad("Barrio Gamma", miembros: [@pilar] + red_relleno(5))
    @pub = red_publicacion(@pilar, titulo: "Instalaciones eléctricas")
    Red::CalculoConfianza.recalcular_todo!
    @secretos = [@beta.nombre, @gamma.nombre, @beta.token, @gamma.token]
  end

  def refute_secretos(contexto = nil)
    @secretos.each { |s| refute_includes response.body, s, "#{contexto}: se filtró «#{s}»" }
  end

  # (El catálogo /red/comunidades lista todas las certificadas a propósito: no las asocia a nadie.)
  test "un administrador de una comunidad no ve en ninguna pantalla las otras comunidades de sus miembros" do
    sign_in @admin_a
    rutas = ["/red/comunidades/#{@alfa.token}/gestion", "/red/comunidades/#{@alfa.token}/gestion/miembros.csv",
             "/red/comunidades/#{@alfa.token}/miembros", "/red/comunidades/#{@alfa.token}", "/red/p/#{@pilar.red_perfil.token}",
             "/red/publicaciones/#{@pub.token}", "/red/buscar?q=el", "/red/buscar?que=personas", "/red/buscar.json?q=el",
             "/red/buscar.json?que=personas", "/red/mi-perfil/datos", "/red/mis-comunidades", "/red",
             "/red/moderacion", "/red/moderacion/metricas", "/red/publicaciones/new", "/red/mi-perfil"]
    rutas.each do |ruta|
      get ruta
      refute_secretos(ruta)
    end
    get "/red/comunidades/#{@alfa.token}/gestion/miembros.csv"
    assert_includes response.body, "Pilar" # está, pero solo con lo de esta comunidad
  end

  test "sin cuenta: perfil, publicación y búsqueda solo dicen cuántas comunidades y una banda" do
    ["/red/p/#{@pilar.red_perfil.token}", "/red/publicaciones/#{@pub.token}", "/red/buscar?q=el", "/red/buscar?que=personas"].each do |ruta|
      get ruta
      assert_response :success
      refute_includes response.body, @alfa.nombre, ruta
      refute_secretos(ruta)
      assert_includes response.body, "3 comunidades certificadas", ruta
    end
    get "/red/p/#{@pilar.red_perfil.token}"
    total = [@alfa, @beta, @gamma].sum { _1.reload.miembros_count }
    assert_includes response.body, "menos de 100 miembros"
    refute_match(/\b#{total}\s+miembros/, response.body)
  end

  test "la API JSON solo trae los campos de la lista blanca, sin ids ni cifras exactas" do
    get "/red/buscar.json?que=personas"
    personas = JSON.parse(response.body)["resultados"]
    assert_equal [@pilar.red_perfil.token], personas.map { _1["token"] }
    assert_equal Red::Ficha::CAMPOS_JSON.sort, personas.first.keys.sort
    assert_equal "menos de 100 miembros", personas.first["banda_miembros"]
    get "/red/buscar.json?q=Instalaciones"
    pub = JSON.parse(response.body)["resultados"].first
    assert_equal (Red::BusquedaController::CAMPOS_PUBLICACION + ["autor"]).sort, pub.keys.sort
    refute_match(/"(id|user_id|comunidad|comunidades_ids|puntaje)"/, response.body)
  end

  test "lo oculto y lo inexistente responden igual: estado, cuerpo y número de consultas" do
    oculta = red_publicacion(@pilar, titulo: "Solo para la universidad", alcance: "elegidas", alcances: [Red::Alcance.new(comunidad: @beta)])
    oculto = red_usuario("Oculto", alcance: "mis_comunidades")
    red_membresia(@beta, oculto)
    [nil, @admin_a].each do |viewer|
      viewer ? sign_in(viewer) : sign_out(:user)
      [["/red/publicaciones/#{oculta.token}", "/red/publicaciones/#{'z' * 24}"],
       ["/red/p/#{oculto.red_perfil.token}", "/red/p/#{'z' * 24}"],
       ["/red/p/#{oculto.red_perfil.token}/hoja-de-vida", "/red/p/#{'z' * 24}/hoja-de-vida"]].each do |escondido, inexistente|
        get escondido # calienta cachés de esquema
        n_escondido = consultas_sql { get escondido }
        cuerpo, estado = sin_aleatorios(response.body), response.status
        n_inexistente = consultas_sql { get inexistente }
        assert_equal 404, estado, escondido
        assert_equal estado, response.status, inexistente
        assert_equal cuerpo, sin_aleatorios(response.body), escondido
        assert_equal n_escondido, n_inexistente, "#{escondido}: las consultas delatan que existe"
      end
    end
  end

  test "un verificador no puede actuar sobre (ni sondear) personas de otra comunidad" do
    sign_in @admin_a
    solicitante = red_usuario("Sole")
    red_membresia(@beta, solicitante, estado: "solicitada")
    post "/red/comunidades/#{@alfa.token}/gestion/#{solicitante.red_perfil.token}/aprobar"
    cuerpo = sin_aleatorios(response.body)
    assert_response :not_found
    post "/red/comunidades/#{@alfa.token}/gestion/#{'z' * 24}/aprobar"
    assert_equal cuerpo, sin_aleatorios(response.body)
    assert_equal "solicitada", @beta.membresias.find_by(user: solicitante).estado
    get "/red/comunidades/#{@beta.token}/gestion" # gestionar una comunidad ajena
    assert_response :not_found
    get "/red/comunidades/#{@beta.token}/miembros" # ni ver su directorio
    assert_response :not_found
  end

  test "filtrar por una comunidad ajena se ignora: mismo resultado que sin filtro" do
    otro = red_usuario("Otro", alcance: "publico")
    red_comunidad("Club Delta", miembros: [otro] + red_relleno(5))
    red_publicacion(otro, titulo: "Clases de guitarra")
    Red::CalculoConfianza.recalcular_todo!
    sign_in @admin_a
    get "/red/buscar.json"
    sin_filtro = JSON.parse(response.body)["resultados"].map { _1["token"] }
    assert_equal 2, sin_filtro.size
    get "/red/buscar.json?comunidad=#{@beta.token}"
    assert_equal sin_filtro, JSON.parse(response.body)["resultados"].map { _1["token"] }
    get "/red/buscar.json?comunidad=#{'q' * 24}"
    assert_equal sin_filtro, JSON.parse(response.body)["resultados"].map { _1["token"] }
    get "/red/buscar.json?comunidad=#{@alfa.token}" # la suya sí filtra
    assert_equal [@pub.token], JSON.parse(response.body)["resultados"].map { _1["token"] }
  end

  test "el orden solo depende del nivel público y la fecha, no de cuáles comunidades" do
    rival = red_usuario("Rival", alcance: "publico", visible_publico: true)
    red_comunidad("Club Épsilon", miembros: [rival] + red_relleno(6))
    reciente = red_publicacion(rival, titulo: "Instalaciones de gas")
    Red::CalculoConfianza.recalcular_todo!
    Red::Confianza.where(user_id: [@pilar.id, rival.id]).update_all(nivel: 2) # mismo nivel público
    get "/red/buscar.json?q=Instalaciones"
    orden = JSON.parse(response.body)["resultados"].map { _1["token"] }
    assert_equal [reciente.token, @pub.token], orden # el más reciente primero, aunque Pilar tenga 3 comunidades
    # Entrar en otra comunidad no mueve nada hasta el lote diario.
    red_comunidad("Club Zeta", miembros: [rival] + red_relleno(30))
    get "/red/buscar.json?q=Instalaciones"
    assert_equal orden, JSON.parse(response.body)["resultados"].map { _1["token"] }
  end

  test "la ficha es una foto: unirse a otra comunidad no cambia nada visible hasta el lote" do
    get "/red/p/#{@pilar.red_perfil.token}"
    antes = sin_aleatorios(response.body)
    red_comunidad("Club Omega", miembros: [@pilar] + red_relleno(20))
    get "/red/p/#{@pilar.red_perfil.token}"
    assert_equal antes, sin_aleatorios(response.body)
  end

  test "el número de consultas no cambia con cuántas comunidades tiene la persona" do
    uno = red_usuario("Uno", alcance: "publico", visible_publico: true)
    red_comunidad(miembros: [uno] + red_relleno(5))
    red_publicacion(uno, titulo: "Instalaciones solares")
    Red::CalculoConfianza.recalcular_todo!
    [uno, @pilar].each { get "/red/p/#{_1.red_perfil.token}" } # calentar
    n_uno = consultas_sql { get "/red/p/#{uno.red_perfil.token}" }
    n_tres = consultas_sql { get "/red/p/#{@pilar.red_perfil.token}" }
    assert_equal n_uno, n_tres
  end

  test "la exportación de una persona trae sus comunidades, nunca las de otros" do
    sign_in @admin_a
    get "/red/mi-perfil/datos"
    datos = JSON.parse(response.body)
    assert_equal ["Club Alfa"], datos["comunidades"].map { _1["comunidad"] }
    refute_secretos("exportación")
  end

  test "las métricas de una comunidad no cuentan lo publicado para otras comunidades" do
    red_publicacion(@pilar, titulo: "Solo Beta", alcance: "elegidas", alcances: [Red::Alcance.new(comunidad: @beta)])
    sign_in @admin_a
    get "/red/comunidades/#{@alfa.token}/gestion"
    refute_includes response.body, "Solo Beta"
    refute_secretos("gestión")
  end
end
