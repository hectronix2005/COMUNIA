require "test_helper"

# «Próximos eventos» en el panel: los eventos del calendario de los próximos 30 días (las reuniones van en su
# tarjeta), del grupo de la persona y de la raíz de su comunidad, con «Asistiré» a un clic.
class ProximosEventosPanelTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @mercedes = logia("Mercedes")
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @socio = persona("Sara", @suv)
    @ruta = evento(@mercedes, "Ruta a Guatavita", 2.days.from_now)
    evento(@suv, "Lavado SUV", 5.days.from_now)
    evento(@clasicos, "Exhibición de clásicos", 3.days.from_now)
    evento(logia("Barrio ajeno"), "Junta de vecinos", 1.day.from_now)
    evento(@suv, "Asado lejano", 60.days.from_now)
    evento(@suv, "Paseo pasado", 2.days.ago)
  end

  test "muestra lo de su grupo y la raíz, no lo de otro grupo, otra comunidad, lo lejano ni lo pasado" do
    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_response :ok
    assert_match "Próximos eventos", response.body
    assert_match "Ruta a Guatavita", response.body
    assert_match "Lavado SUV", response.body
    assert_operator response.body.index("Ruta a Guatavita"), :<, response.body.index("Lavado SUV"), "en orden"
    %w[Exhibición Junta Asado Paseo].each { assert_no_match it, response.body }
    assert_match "Ver en mi teléfono", response.body
  end

  test "confirmar desde el panel queda registrado y se ve" do
    sign_in @socio
    post "/t/#{@mercedes.slug}/calendario/#{@ruta.id}/evento_confirmaciones", params: { estado: "confirmado" },
                                                                             headers: { "HTTP_REFERER" => "http://www.example.com/t/#{@mercedes.slug}/dashboard" }
    assert_redirected_to "http://www.example.com/t/#{@mercedes.slug}/dashboard"
    assert @ruta.evento_confirmaciones.confirmados.exists?(user: @socio)

    get "/t/#{@mercedes.slug}/dashboard"
    assert_match "Vas a ir", response.body
  end

  test "la reunión no se repite como evento" do
    inicio = 4.days.from_now.change(hour: 19)
    Reunion.create!(logia: @mercedes, user: @socio, titulo: "Asamblea anual", inicio: inicio, fin: inicio + 2.hours)
    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_equal 1, response.body.scan("Asamblea anual").size
  end

  private

  def logia(nombre, tenant: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant)
  end

  def evento(logia, titulo, inicio)
    CalendarioEvento.create!(logia: logia, user: @socio, titulo: titulo, inicio: inicio, fin: inicio + 1.hour)
  end

  def persona(nombre, logia)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol_miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
