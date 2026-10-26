require "test_helper"

# Suscripción al calendario desde el teléfono: cada quien crea su dirección secreta y su app de calendario la pide
# sola, sin sesión. Lleva lo que esa persona ve en el calendario de la app y nada de otra comunidad.
class SuscripcionCalendarioTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @club = logia("Club Mercedes")
    @socio = persona("Sara", @club)
    inicio = 3.days.from_now.change(hour: 9)
    @reunion = Reunion.create!(logia: @club, user: @socio, titulo: "Ruta a Guatavita", inicio: inicio, fin: inicio + 3.hours)
    CalendarioEvento.create!(logia: @club, user: @socio, titulo: "Asado de fin de año", inicio: 20.days.from_now,
                             fin: 20.days.from_now + 2.hours)
    CalendarioEvento.create!(logia: @club, user: @socio, titulo: "Viaje viejo", inicio: 3.months.ago, fin: 3.months.ago + 1.hour)
  end

  test "se crea la dirección y el teléfono baja sus eventos sin sesión" do
    sign_in @socio
    get "/t/#{@club.slug}/calendario/suscripcion"
    assert_response :ok
    assert_match "Crear mi dirección", response.body

    post "/t/#{@club.slug}/calendario/suscripcion"
    token = @socio.reload.calendario_token
    assert_match(/\A\h{64}\z/, token)
    follow_redirect!
    assert_match "no-store", response.headers["Cache-Control"]
    assert_match "http://www.example.com/calendario/feed.ics?token=#{token}", response.body, "sin /t/<slug>"
    assert_match "webcal://www.example.com/calendario/feed.ics?token=#{token}", response.body
    assert_match "calendar.google.com/calendar/render?cid=webcal", response.body

    sign_out :user
    get "/calendario/feed.ics", params: { token: token }
    assert_response :ok
    assert_equal "text/calendar", response.media_type
    assert_match "no-store", response.headers["Cache-Control"]
    ics = response.body.gsub("\r\n ", "")
    assert_includes ics, "X-WR-CALNAME:Club Mercedes"
    assert_includes ics, "REFRESH-INTERVAL;VALUE=DURATION:PT4H"
    assert_includes ics, "SUMMARY:Reunión: Ruta a Guatavita"
    assert_includes ics, "URL:http://www.example.com/t/#{@club.slug}/reuniones/#{@reunion.id}"
    assert_includes ics, "SUMMARY:Asado de fin de año"
    assert_not_includes ics, "Viaje viejo", "lo de hace meses no viaja"
    assert_equal 2, ics.scan("BEGIN:VEVENT").size
  end

  test "no lleva nada de otra comunidad" do
    ajena = logia("Vecinos Cedritos")
    CalendarioEvento.create!(logia: ajena, user: persona("Abel", ajena), titulo: "Junta de vecinos",
                             inicio: 2.days.from_now, fin: 2.days.from_now + 1.hour)
    @socio.renovar_calendario!
    get "/calendario/feed.ics", params: { token: @socio.calendario_token }
    assert_response :ok
    assert_not_includes response.body, "Junta de vecinos"
    assert_not_includes response.body, "Cedritos"
  end

  test "una dirección cambiada, anulada, inventada o de quien ya no está no sirve" do
    @socio.renovar_calendario!
    vieja = @socio.calendario_token
    sign_in @socio
    post "/t/#{@club.slug}/calendario/suscripcion"
    nueva = @socio.reload.calendario_token
    assert_not_equal vieja, nueva

    get "/calendario/feed.ics", params: { token: vieja }
    assert_response :not_found
    get "/calendario/feed.ics", params: { token: nueva[0, 24] + ("0" * 40) }
    assert_response :not_found, "la semilla sola no basta: hace falta la firma"
    get "/calendario/feed.ics", params: { token: { "$ne" => "" } }
    assert_response :not_found
    get "/calendario/feed.ics"
    assert_response :not_found

    @socio.miembro.update!(estado: :quite, estado_desde: Date.yesterday)
    get "/calendario/feed.ics", params: { token: nueva }
    assert_response :not_found, "quien dejó la comunidad deja de recibirlo"
    @socio.miembro.update!(estado: :activo, estado_desde: nil)
    get "/calendario/feed.ics", params: { token: nueva }
    assert_response :ok

    delete "/t/#{@club.slug}/calendario/suscripcion"
    assert_nil @socio.reload.calendario_semilla
    get "/calendario/feed.ics", params: { token: nueva }
    assert_response :not_found
  end

  test "sin sesión no se crea ni se ve la dirección" do
    get "/t/#{@club.slug}/calendario/suscripcion"
    assert_redirected_to "http://www.example.com/login"
    post "/t/#{@club.slug}/calendario/suscripcion"
    assert_nil @socio.reload.calendario_semilla
  end

  private

  def logia(nombre)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}", codigo: "L#{SecureRandom.hex(3).upcase}")
  end

  def persona(nombre, logia)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol_miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
