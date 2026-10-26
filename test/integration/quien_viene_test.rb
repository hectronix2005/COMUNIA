require "test_helper"

# Quién viene: quien gestiona la convocatoria ve los nombres de quienes confirman, no pueden o no han respondido, y
# puede preguntar por WhatsApp a quien no ha respondido (si ya entra en la app y tiene teléfono). Los demás, solo
# los totales.
class QuienVieneTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @admin, = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio, = persona("Sara", @suv)
    @callado, ficha_callado = persona("Simón", @suv)
    ficha_callado.update!(telefono: "300 123 4567")
    @callado.update_column(:last_seen_at, 1.day.ago)
    persona("Nora", @suv) # nunca ha entrado
    inicio = 2.days.from_now.change(hour: 19)
    @reunion = Reunion.create!(logia: @suv, user: @admin, titulo: "Ruta", inicio: inicio, fin: inicio + 2.hours)
    @base = "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"
  end

  test "quien gestiona ve quién confirma, quién no y a quién preguntar" do
    sign_in @socio
    post "#{@base}/responder", params: { estado: "confirmado" }
    get @base
    assert_not_includes response.body, "Ver quién", "un socio solo ve los totales"

    sign_in @admin
    get @base
    cuerpo = response.body
    assert_match(/Confirman \(1\)\s*<\/div>\s*<div[^>]*>\s*<span>Sara Prueba/, cuerpo)
    assert_includes cuerpo, "No pueden (0)"
    assert_includes cuerpo, "Sin responder (3)"
    assert_match(/Nora Prueba<\/span>\s*<span class="text-muted">· aún no entra en la app/, cuerpo)
    pregunta = cuerpo[%r{href="(https://wa\.me/573001234567\?text=[^"]+)"}, 1]
    assert pregunta, "a Simón, que entra y tiene teléfono, se le puede preguntar"
    assert_includes CGI.unescape(CGI.unescapeHTML(pregunta)), "Hola, Simón. ¿Vienes a «Ruta»"
    assert_equal 1, cuerpo.scan("wa.me/57").size, "solo a quien entra y tiene teléfono"
  end

  private

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    ficha = Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo)
    [user, ficha]
  end
end
