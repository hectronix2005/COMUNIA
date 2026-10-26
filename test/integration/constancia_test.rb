require "test_helper"

# Constancia: de las reuniones celebradas en el último año a las que se convocó a cada miembro (su grupo y la raíz,
# desde que tiene ficha), a cuántas asistió. Quien gestiona la ve de su grupo; cada miembro, la suya.
class ConstanciaTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @admin, = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio, @ficha_socio = persona("Sara", @suv)
    @otro_socio, @ficha_otro = persona("Simón", @suv)
    _, @ficha_vecino = persona("Vera", @clasicos)

    @r1 = celebrada(@suv, 40.days.ago)
    r2 = celebrada(@suv, 30.days.ago)
    r3 = celebrada(@suv, 20.days.ago)
    @general = celebrada(@mercedes, 10.days.ago) # en la raíz: convoca a toda la comunidad
    celebrada(@clasicos, 15.days.ago, asistentes: [@ficha_vecino])
    celebrada(@suv, 400.days.ago, asistentes: [@ficha_otro]) # hace más de un año
    Reunion.create!(logia: @suv, user: @admin, titulo: "Sin registrar", inicio: 5.days.ago, fin: 5.days.ago + 2.hours)
    [@r1, @general].each { _1.reunion_asistencias.create!(miembro: @ficha_socio) }
    @r1.reunion_asistencias.create!(miembro: @ficha_otro)
    [r2, r3].each { _1.reunion_asistencias.create!(miembro: @ficha_vecino) } # de otro grupo: no cuenta
  end

  test "quien gestiona ve primero a quien menos viene, sin otros grupos" do
    sign_in @admin
    get "/t/#{@mercedes.slug}/reuniones/constancia"
    assert_response :ok
    cuerpo = response.body
    assert_includes cuerpo, "1 de 4"
    assert_includes cuerpo, "3 seguidas sin venir"
    assert_includes cuerpo, "2 de 4"
    assert cuerpo.index("Simón Prueba") < cuerpo.index("Sara Prueba"), "primero quien menos viene"
    assert_not_includes cuerpo, "Vera Prueba"

    constancia = Reunion.constancia(Miembro.where(id: @ficha_socio.id)).sole
    assert_equal [4, 2, 50, 0], [constancia.convocadas, constancia.asistidas, constancia.porcentaje, constancia.faltas_seguidas]
    assert_equal @general.inicio.to_i, constancia.ultima.to_i
  end

  test "quien llegó después no cuenta lo de antes, y cada miembro ve solo la suya" do
    _, nuevo = persona("Nico", @suv, desde: 15.days.ago)
    assert_equal [1, 0], Reunion.constancia(Miembro.where(id: nuevo.id)).sole.then { [_1.convocadas, _1.asistidas] }

    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones"
    assert_includes response.body, "Tu asistencia en el último año: <strong>2 de 4</strong>"
    get "/t/#{@mercedes.slug}/reuniones/constancia"
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones"
    assert_not_includes response.body, "Simón"
  end

  private

  def celebrada(logia, inicio, asistentes: [])
    reunion = Reunion.create!(logia: logia, user: @admin, titulo: "Encuentro #{SecureRandom.hex(2)}", inicio: inicio, fin: inicio + 2.hours)
    reunion.update_column(:estado, Reunion.estados[:celebrada])
    asistentes.each { reunion.reunion_asistencias.create!(miembro: _1) }
    reunion
  end

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro, desde: 2.years.ago)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    ficha = Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo, created_at: desde)
    [user, ficha]
  end
end
