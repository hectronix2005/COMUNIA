require "test_helper"

# Comunidades sombrilla (Sombrilla, SombrillasController, SombrillaContenidosController): barrio → localidad →
# ciudad sin admin. Se está dentro por ser de una comunidad de categoría Barrio anclada a un barrio; cada uno
# elige cómo aparece; lo reportado por 3 comunidades se oculta solo; moderan los admins de abajo y el superadmin.
class SombrillasTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba
  include ActiveJob::TestHelper

  setup do
    preparar_denuncias
    @categoria = Categoria.find_or_create_by!(nombre: "Barrio")
    marca = SecureRandom.hex(3)
    @ciudad = Sombrilla.create!(nombre: "Ciudad #{marca}", nivel: "ciudad")
    @localidad = Sombrilla.create!(nombre: "Localidad #{marca}", nivel: "localidad", padre: @ciudad)
    @otra_localidad = Sombrilla.create!(nombre: "Otra #{marca}", nivel: "localidad", padre: @ciudad)
    @barrio = Sombrilla.create!(nombre: "Barrio #{marca}", nivel: "barrio", padre: @localidad)
    @barrio2 = Sombrilla.create!(nombre: "Vecino #{marca}", nivel: "barrio", padre: @localidad)
    @barrio3 = Sombrilla.create!(nombre: "Lejano #{marca}", nivel: "barrio", padre: @otra_localidad)

    @ana = anclada("Ana", @barrio)
    @beto = anclada("Beto", @barrio2)
    @carla = anclada("Carla", @barrio3)
    @admin = anclada("Adela", @barrio2, rol: "admin_logia")
    @fuera = vecino("Fede") # su comunidad no está en ningún barrio
  end

  teardown { limpiar_denuncias }

  def anclada(nombre, barrio, rol: "miembro")
    user = vecino(nombre, rol: rol)
    user.logia.update!(categoria: @categoria, sombrilla: barrio)
    user
  end

  def ruta(user, sombrilla, resto = "") = "/t/#{user.logia.slug}/sombrillas/#{sombrilla.slug}#{resto}"
  def contenido(user, tipo, registro, accion = "") = "/t/#{user.logia.slug}/sombrillas/#{tipo}/#{registro.id}#{accion}"

  test "la membresía se calcula: el barrio trae su localidad y su ciudad; lo ajeno es un 404" do
    assert_equal [@barrio, @localidad, @ciudad], Sombrilla.de_usuario(@ana).to_a
    assert_equal [@barrio3, @otra_localidad, @ciudad], Sombrilla.de_usuario(@carla).to_a
    assert_empty Sombrilla.de_usuario(@fuera)

    sign_in @ana
    get ruta(@ana, @barrio)
    assert_response :success
    assert_select "a", text: /#{@ciudad.nombre}/
    get ruta(@ana, @barrio2)
    assert_response :not_found
    assert_equal @ana.logia, @ana.reload.logia, "mirar la sombrilla no cambia la comunidad activa"
    sign_out :user

    sign_in @fuera
    get "/t/#{@fuera.logia.slug}/sombrillas"
    assert_response :success
    assert_match "aún no está en ningún barrio", response.body
    get ruta(@fuera, @ciudad)
    assert_response :not_found
  end

  test "solo se anclan comunidades de categoría Barrio, y a un barrio" do
    club = vecino("Clara").logia
    club.update!(categoria: Categoria.find_or_create_by!(nombre: "Club"))
    assert_not club.update(sombrilla: @barrio)
    @ana.logia.reload
    assert_not @ana.logia.update(sombrilla: @localidad)
    assert_not Sombrilla.new(nombre: "Sin localidad", nivel: "barrio", padre: @ciudad).valid?
  end

  test "cada uno elige cómo aparece antes de publicar, y los moderadores ven el nombre completo" do
    sign_in @ana
    get ruta(@ana, @localidad)
    assert_match "¿Cómo quieres aparecer", response.body
    assert_no_difference -> { SombrillaPublicacion.count } do
      post ruta(@ana, @localidad, "/publicar"), params: { sombrilla_publicacion: { contenido: "Hola" } }
    end

    patch "/t/#{@ana.logia.slug}/sombrillas/visibilidad", params: { visibilidad: "todo" }
    assert_nil @ana.reload.visibilidad_sombrilla
    patch "/t/#{@ana.logia.slug}/sombrillas/visibilidad", params: { visibilidad: "anonimo" }
    assert_equal "anonimo", @ana.reload.visibilidad_sombrilla

    post ruta(@ana, @localidad, "/publicar"), params: { sombrilla_publicacion: { contenido: "Se perdió un gato <b>gris</b>" } }
    pub = SombrillaPublicacion.last
    assert_equal [@localidad, @ana.logia], [pub.sombrilla, pub.comunidad]
    sign_out :user

    sign_in @beto
    get ruta(@beto, @localidad)
    assert_match "Miembro de #{@ana.logia.nombre}", response.body
    assert_no_match "Ana Prueba", response.body
    assert_match "Se perdió un gato &lt;b&gt;gris&lt;/b&gt;", response.body
    get ruta(@beto, @barrio)
    assert_response :not_found, "la de Ana en su barrio no le llega a Beto, que es de otro barrio"
    sign_out :user

    sign_in @admin
    get ruta(@admin, @localidad)
    assert_match "(Ana Prueba)", response.body

    @ana.update_column(:visibilidad_sombrilla, "inicial")
    get ruta(@admin, @localidad)
    assert_match "Ana P. · #{@ana.logia.nombre}", response.body
  end

  test "lo reportado por tres comunidades se oculta; los admins de abajo ocultan y muestran" do
    [@ana, @beto, @carla, @admin].each { _1.update_column(:visibilidad_sombrilla, "inicial") }
    pub = @ciudad.publicaciones.create!(user: @ana, comunidad: @ana.logia, contenido: "Oferta dudosa")
    vecino_de_beto = vecino("Bruno")
    vecino_de_beto.update!(logia: @beto.logia)

    [@beto, vecino_de_beto].each do |quien|
      sign_in quien
      post contenido(quien, "publicacion", pub, "/reportar")
      sign_out :user
    end
    assert_not pub.reload.oculta, "dos personas de la misma comunidad cuentan como una"

    sign_in @beto
    patch contenido(@beto, "publicacion", pub, "/ocultar")
    assert_response :forbidden
    sign_out :user

    sign_in @carla
    post contenido(@carla, "publicacion", pub, "/reportar")
    assert_not pub.reload.oculta, "van dos comunidades"
    sign_out :user

    dora = anclada("Dora", @barrio)
    sign_in dora
    post contenido(dora, "publicacion", pub, "/reportar")
    assert pub.reload.oculta, "la tercera comunidad la oculta"
    sign_out :user

    sign_in @carla
    get ruta(@carla, @ciudad)
    assert_no_match "Oferta dudosa", response.body
    post contenido(@carla, "publicacion", pub, "/comentar"), params: { contenido: "x" }
    assert_response :not_found
    sign_out :user

    sign_in @admin
    get ruta(@admin, @ciudad)
    assert_match "Oferta dudosa", response.body
    patch contenido(@admin, "publicacion", pub, "/mostrar")
    assert_not pub.reload.oculta
    patch contenido(@admin, "publicacion", pub, "/ocultar")
    assert pub.reload.oculta
    sign_out :user

    # El admin de otra rama (Carla no lo es) no modera; el de una comunidad sin barrio no entra.
    assert_not @localidad.modera?(@carla)
    assert @localidad.modera?(@admin)
    assert_not @barrio.modera?(@admin), "Adela es admin en el barrio vecino, no en el de Ana"
  end

  test "comentar, borrar lo propio y eventos" do
    [@ana, @beto].each { _1.update_column(:visibilidad_sombrilla, "completo") }
    pub = @localidad.publicaciones.create!(user: @ana, comunidad: @ana.logia, contenido: "Jornada de aseo")

    sign_in @beto
    post contenido(@beto, "publicacion", pub, "/comentar"), params: { contenido: "Cuenten conmigo" }
    comentario = pub.comentarios.last
    assert_equal [@beto, @beto.logia], [comentario.user, comentario.comunidad]
    delete contenido(@beto, "publicacion", pub)
    assert_response :forbidden
    delete contenido(@beto, "comentario", comentario)
    assert_not SombrillaComentario.exists?(comentario.id)

    post ruta(@beto, @ciudad, "/crear_evento"), params: { sombrilla_evento: { titulo: "Feria", inicio: 2.days.from_now.strftime("%Y-%m-%dT%H:%M"), lugar: "Parque" } }
    get ruta(@beto, @ciudad, "/eventos")
    assert_match "Feria", response.body
    assert_match "Beto Prueba · #{@beto.logia.nombre}", response.body
    sign_out :user

    sign_in @carla
    get ruta(@carla, @ciudad, "/eventos")
    assert_match "Feria", response.body
    post contenido(@carla, "publicacion", pub, "/comentar"), params: { contenido: "x" }
    assert_response :not_found, "Carla no llega a la localidad de Ana"
  end

  test "el superadmin lleva el catálogo; los demás no" do
    sign_in @ana
    post "/t/#{@ana.logia.slug}/sombrillas/crear", params: { nombre: "Colado", padre_id: @localidad.id }
    assert_response :not_found
    sign_out :user

    super_admin = vecino("Sara", rol: "super_admin")
    sign_in super_admin
    base = "/t/#{super_admin.logia.slug}/sombrillas"
    get base
    assert_select "h6", text: "Barrio nuevo"
    post "#{base}/crear", params: { nombre: "Nuevo #{SecureRandom.hex(2)}", padre_id: @localidad.id }
    nuevo = Sombrilla.barrios.order(:id).last
    assert_equal @localidad, nuevo.padre

    patch "#{base}/anclar", params: { logia_id: @carla.logia.id, sombrilla_id: nuevo.id }
    assert_equal nuevo, @carla.logia.reload.sombrilla
    patch "#{base}/anclar", params: { logia_id: @carla.logia.id, sombrilla_id: "" }
    assert_nil @carla.logia.reload.sombrilla

    get ruta(super_admin, @barrio)
    assert_response :success
    assert_match "Miras como superadmin", response.body
  end

  test "noticias de las sombrillas con gente; el tipo sale de una lista blanca" do
    rss = <<~XML
      <rss><channel><item><title>Cierre vial en la zona - El Tiempo</title><link>https://news.google.com/rss/articles/a</link>
      <pubDate>#{1.day.ago.rfc2822}</pubDate><source url="https://eltiempo.com">El Tiempo</source></item></channel></rss>
    XML
    pedidas = []
    Noticias::GoogleNoticias.descargador = ->(url) { pedidas << url; rss }
    perform_enqueued_jobs { ActualizarNoticiasJob.perform_now }
    con_gente = [@barrio, @barrio2, @barrio3, @localidad, @otra_localidad, @ciudad]
    assert_equal con_gente.map(&:id).sort, Noticia.where(sombrilla: con_gente).distinct.pluck(:sombrilla_id).sort

    noticia = @ciudad.noticias.first
    sign_in @admin
    get ruta(@admin, @ciudad, "/noticias")
    assert_match "Cierre vial en la zona", response.body
    patch contenido(@admin, "noticia", noticia, "/ocultar")
    assert noticia.reload.oculta
    sign_out :user

    sign_in @ana
    get ruta(@ana, @ciudad, "/noticias")
    assert_no_match "Cierre vial en la zona", response.body
    de_comunidad = @fuera.logia.noticias.create!(titulo: "Ajena", url: "https://news.google.com/x", publicada_en: Time.current)
    patch contenido(@ana, "noticia", de_comunidad, "/ocultar")
    assert_response :not_found
    patch "/t/#{@ana.logia.slug}/sombrillas/user/#{@ana.id}/ocultar"
    assert_response :not_found
  ensure
    Noticias::GoogleNoticias.descargador = nil
  end
end
