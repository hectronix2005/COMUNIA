require "test_helper"

# «Añadir a mi calendario»: cada evento (y cada reunión, a través de su evento) se baja como .ics o se abre en
# Google Calendar, para que avise el calendario del teléfono. Solo para quien ve el evento.
class AnadirAlCalendarioTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro", modulos: %w[reuniones])
    @club = Logia.create!(nombre: "Club BMW", slug: "bmw-#{SecureRandom.hex(3)}", codigo: "B#{SecureRandom.hex(3).upcase}", categoria: club)
    @socio = persona("Sara", @club)
    inicio = Time.zone.local(2026, 11, 14, 9, 30)
    @reunion = Reunion.create!(logia: @club, user: @socio, titulo: "Ruta; Villa de Leyva, con desayuno", inicio: inicio,
                               fin: inicio + 3.hours, lugar: "Peaje Andes", orden_del_dia: "1. Salida\n2. Desayuno")
  end

  test "la reunión ofrece el .ics y el enlace de Google, y el .ics trae los datos escapados" do
    sign_in @socio
    get "/t/#{@club.slug}/reuniones/#{@reunion.id}"
    assert_match "Añadir a mi calendario", response.body
    assert_match "calendar.google.com/calendar/render?action=TEMPLATE", response.body
    assert_match "dates=20261114T143000Z%2F20261114T173000Z", response.body
    assert_no_match "Desayuno", response.body[/calendar\.google\.com[^"]+/], "la descripción no va a Google"

    get "/t/#{@club.slug}/calendario/#{@reunion.calendario_evento_id}.ics"
    assert_response :ok
    assert_equal "text/calendar", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "no-store", response.headers["Cache-Control"]
    ics = response.body
    assert ics.start_with?("BEGIN:VCALENDAR\r\n")
    assert_includes ics, "DTSTART:20261114T143000Z\r\n"
    assert_includes ics, "SUMMARY:Encuentro: Ruta\\; Villa de Leyva\\, con desayuno"
    assert_includes ics, "LOCATION:Peaje Andes"
    assert_includes ics.gsub("\r\n ", ""), "DESCRIPTION:1. Salida\\n2. Desayuno\\n\\nhttp://www.example.com/t/#{@club.slug}/reuniones/#{@reunion.id}"
    assert ics.split("\r\n").all? { _1.bytesize <= 75 }, "líneas plegadas"
  end

  test "un evento de otra comunidad no se baja y sin sesión se pide entrar" do
    ajena = Logia.create!(nombre: "Barrio", slug: "barrio-#{SecureRandom.hex(3)}", codigo: "BA#{SecureRandom.hex(3).upcase}")
    evento = CalendarioEvento.create!(logia: ajena, user: persona("Abel", ajena), titulo: "Privado", inicio: 1.day.from_now,
                                      fin: 1.day.from_now + 1.hour)
    sign_in @socio
    get "/t/#{@club.slug}/calendario/#{evento.id}.ics"
    assert_response :not_found

    sign_out :user
    get "/t/#{@club.slug}/calendario/#{@reunion.calendario_evento_id}.ics"
    assert_not_equal 200, response.status
    assert_no_match "BEGIN:VCALENDAR", response.body
  end

  test "un evento de todo el día va con fechas, y el texto largo se pliega sin partir letras" do
    ics = Ics.evento(uid: "x@comunia", titulo: "Cumpleaños de ñandú " * 8, inicio: Time.zone.local(2026, 12, 24),
                     fin: Time.zone.local(2026, 12, 25), todo_el_dia: true)
    assert_includes ics, "DTSTART;VALUE=DATE:20261224\r\n"
    assert_includes ics, "DTEND;VALUE=DATE:20261226\r\n"
    assert ics.split("\r\n").all? { _1.valid_encoding? && _1.bytesize <= 75 }
    assert_includes ics.gsub("\r\n ", ""), "SUMMARY:#{'Cumpleaños de ñandú ' * 8}".strip
  end

  private

  def persona(nombre, logia)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol_miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
