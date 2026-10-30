require "test_helper"

# Los avisos no se mezclan entre comunidades: quien pertenece a dos ve en cada una solo los suyos y los personales
# (la red); de la otra, cuántos tiene sin leer. El enlace de cada aviso abre su comunidad, y los de una comunidad
# que la persona dejó ya no salen.
class NotificacionesPorComunidadTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @luz = Logia.create!(nombre: "Logia Luz", slug: "luz-#{SecureRandom.hex(2)}", codigo: "L#{SecureRandom.hex(3).upcase}")
    @andes = Logia.create!(nombre: "Egresados Andes", slug: "andes-#{SecureRandom.hex(2)}", codigo: "A#{SecureRandom.hex(3).upcase}")
    @grupo = Logia.create!(nombre: "Cohorte 2023", slug: "c23-#{SecureRandom.hex(2)}", codigo: "C#{SecureRandom.hex(3).upcase}", tenant: @andes)

    @ana = User.create!(nombre: "Ana", apellido: "Dos", email: "ana_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @luz, rol_ref: @rol_miembro)
    @ana.unir_a_comunidad!(@andes)

    @de_luz = aviso(@luz, "Tenida del jueves", "/reuniones/1")
    @de_andes = aviso(@grupo, "Asado de la cohorte", "/calendario/2")
    @de_la_red = NotificacionService.crear!(user: @ana, tipo: "red_aviso", titulo: "Tu comunidad fue certificada", url: "/red")
  end

  test "en cada comunidad solo salen sus avisos y los personales" do
    sign_in @ana
    get "/t/#{@luz.slug}/notificaciones"
    assert_response :success
    assert_includes response.body, "Tenida del jueves"
    assert_includes response.body, "Tu comunidad fue certificada"
    assert_not_includes response.body, "Asado de la cohorte"
    assert_select "a[href='/t/#{@andes.slug}/dashboard']", text: /Egresados Andes/
    assert_select "a[href='/t/#{@luz.slug}/reuniones/1']"

    get "/t/#{@andes.slug}/notificaciones"
    assert_includes response.body, "Asado de la cohorte"
    assert_not_includes response.body, "Tenida del jueves"
    assert_select "a[href='/t/#{@andes.slug}/calendario/2']"
  end

  test "el contador y marcar todas leídas son de la comunidad que se mira" do
    sign_in @ana
    get "/t/#{@luz.slug}/dashboard"
    assert_select "#notification-badge", text: "2"

    post "/t/#{@luz.slug}/notificaciones/leer_todas"
    assert @de_luz.reload.leida
    assert @de_la_red.reload.leida
    assert_not @de_andes.reload.leida
  end

  test "los avisos de una comunidad que dejó ya no salen en ninguna parte" do
    @ana.salir_de_comunidad!(@andes)
    sign_in @ana
    get "/t/#{@luz.slug}/notificaciones"
    assert_not_includes response.body, "Asado de la cohorte"
    assert_not_includes response.body, "En tus otras comunidades"

    get "/t/#{@andes.slug}/notificaciones"
    assert_redirected_to "/dashboard"
  end

  test "el enlace del aviso lleva el prefijo de su comunidad, también en el teléfono" do
    assert_equal "/t/#{@andes.slug}/calendario/2", @de_andes.enlace
    assert_equal "/red", @de_la_red.enlace
    assert_equal "Red", @de_la_red.origen
    assert_nil @de_luz.origen
    assert_equal "/t/#{@luz.slug}/dashboard", aviso(@luz, "Sin enlace", nil).enlace
  end

  private

  def aviso(logia, titulo, url)
    NotificacionService.crear!(user: @ana, tipo: "evento_recordatorio", titulo: titulo, url: url, logia: logia)
  end
end
