require "test_helper"

# Noticias de internet por comunidad (NoticiasController, ActualizarNoticiasJob, Noticias::GoogleNoticias): las
# enciende el admin de la comunidad, se traen de Google Noticias y el admin oculta las que no sirvan.
class NoticiasTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba
  include ActiveJob::TestHelper

  RSS = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel>
      <item><title>Los Andes abre becas - El Tiempo</title><link>https://news.google.com/rss/articles/uno</link>
        <pubDate>Sun, 01 Nov 2026 13:00:00 GMT</pubDate><source url="https://www.eltiempo.com">El Tiempo</source></item>
      <item><title>Sin enlace seguro - Medio</title><link>http://inseguro.example/x</link>
        <pubDate>Sun, 01 Nov 2026 13:00:00 GMT</pubDate><source url="https://x.example">Medio</source></item>
      <item><title>&lt;script&gt;alert(1)&lt;/script&gt; Egresados - Semana</title><link>https://news.google.com/rss/articles/dos</link>
        <pubDate>Sat, 31 Oct 2026 10:00:00 GMT</pubDate><source url="https://www.semana.com">Semana</source></item>
    </channel></rss>
  XML

  setup do
    preparar_denuncias
    @admin = vecino("Ada", rol: "admin_logia")
    @comunidad = @admin.logia
    @miembro = vecino("Mario")
    @miembro.update!(logia: @comunidad)
    @pedidas = []
    Noticias::GoogleNoticias.descargador = ->(url) { @pedidas << url; RSS }
  end

  teardown do
    Noticias::GoogleNoticias.descargador = nil
    limpiar_denuncias
  end

  def ruta(resto = "") = "/t/#{@comunidad.slug}/noticias#{resto}"

  test "lee titular, medio, fecha y enlace; descarta lo que no es https" do
    leidas = Noticias::GoogleNoticias.leer(RSS)
    assert_equal ["Los Andes abre becas", "<script>alert(1)</script> Egresados"], leidas.map { _1[:titulo] }
    assert_equal "El Tiempo", leidas.first[:medio]
    assert_equal Time.utc(2026, 11, 1, 13), leidas.first[:publicada_en]
    assert_includes Noticias::GoogleNoticias.url("Universidad de los Andes"), "q=Universidad+de+los+Andes+when%3A30d"
  end

  test "el admin las enciende con sus búsquedas, se traen y los miembros las ven escapadas" do
    sign_in @admin
    get ruta
    assert_redirected_to "/t/#{@comunidad.slug}/noticias/configuracion"
    follow_redirect!
    assert_select "input[name='noticias[busquedas][]'][value=?]", @comunidad.nombre

    perform_enqueued_jobs do
      patch ruta("/configuracion"), params: { noticias: { activas: "1", busquedas: ["Universidad de los Andes", "", " universidad DE LOS ANDES "] } }
    end
    assert_equal ["Universidad de los Andes"], @comunidad.reload.noticias_busquedas
    assert_equal 1, @pedidas.size
    assert_equal 2, @comunidad.noticias.count

    sign_out :user
    sign_in @miembro
    get ruta
    assert_response :ok
    assert_includes response.body, "Los Andes abre becas"
    assert_includes response.body, "&lt;script&gt;"
    assert_select "a[href='https://news.google.com/rss/articles/uno'][rel='noopener noreferrer nofollow']"
    assert_select "button", text: "Ocultar", count: 0
  end

  test "el miembro no configura ni oculta, y sin Noticias encendidas vuelve al inicio" do
    sign_in @miembro
    get ruta
    assert_redirected_to "/t/#{@comunidad.slug}/dashboard"
    patch ruta("/configuracion"), params: { noticias: { activas: "1", busquedas: ["x y z"] } }
    assert_not @comunidad.reload.noticias_activas
  end

  test "el admin oculta una noticia: los miembros dejan de verla y él puede mostrarla otra vez" do
    @comunidad.update!(noticias_activas: true, noticias_busquedas: ["Los Andes"])
    ActualizarNoticiasJob.perform_now(@comunidad.id)
    noticia = @comunidad.noticias.find_by!(titulo: "Los Andes abre becas")

    sign_in @admin
    patch ruta("/#{noticia.id}/ocultar")
    assert noticia.reload.oculta
    get ruta("?ocultas=1")
    assert_includes response.body, "Mostrar"

    sign_out :user
    sign_in @miembro
    get ruta
    assert_not_includes response.body, "Los Andes abre becas"
  end

  test "repetir la búsqueda no duplica, no resucita las ocultas y no toca otras comunidades" do
    otra = vecino("Otra", rol: "admin_logia").logia
    otra.update!(noticias_activas: true, noticias_busquedas: ["Otra cosa"])
    @comunidad.update!(noticias_activas: true, noticias_busquedas: ["Los Andes"])
    ActualizarNoticiasJob.perform_now
    @comunidad.noticias.first.update!(oculta: true)
    ActualizarNoticiasJob.perform_now(@comunidad.id)
    assert_equal 2, @comunidad.noticias.count
    assert_equal 1, @comunidad.noticias.where(oculta: true).count

    sign_in @admin
    patch ruta("/#{otra.noticias.first.id}/ocultar")
    assert_response :not_found
  end

  test "el admin de un grupo no configura las noticias de toda la comunidad" do
    grupo = Logia.create!(nombre: "Grupo", codigo: "G#{SecureRandom.hex(2).upcase}", tenant: @comunidad)
    admin_grupo = vecino("Gabo", rol: "admin_logia")
    admin_grupo.update!(logia: grupo)
    sign_in admin_grupo
    get ruta("/configuracion")
    assert_redirected_to "/t/#{@comunidad.slug}/dashboard"
  end

  test "solo hasta tres búsquedas, y encender exige al menos una" do
    @comunidad.noticias_activas = true
    @comunidad.noticias_busquedas = []
    assert_not @comunidad.valid?
    @comunidad.noticias_busquedas = %w[uno dos tres cuatro]
    assert_not @comunidad.valid?
  end
end
