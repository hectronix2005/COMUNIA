require "test_helper"

# Resumen diario del rastreo (ResumenRastreo y ResumenRastreoJob): lo que llega a los superadmins a las 9 p. m.
class ResumenRastreoTest < ActiveSupport::TestCase
  include DenunciasPrueba

  setup do
    @nelson = vecino("Nelson")
    @david = vecino("David")
    @hernan = vecino("Hernán")
    # Como los genera la ficha del miembro: enlace sin correo, así que invitation_sent_at queda vacío.
    [@david, @hernan].each { _1.update_columns(invitation_token: SecureRandom.hex(8), invitation_created_at: 1.day.ago) }
    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    @super = User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                          password: "password123", rol_ref: rol)
  end

  def visita(user = nil)
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, user:, started_at: Time.current)
  end

  def evento(visita, name, properties = {}, time: Time.current)
    Ahoy::Event.create!(visit: visita, user: visita.user, name:, properties:, time:)
  end

  def vista(visita, titulo, segundos)
    evento(visita, "$view", { title: "#{titulo} — FREEMASONS" })
    evento(visita, "Tiempo en vista", { segundos_visible: segundos })
  end

  test "dice quién entró, cuánto estuvo, hasta dónde llegó, quién abrió la invitación, quién falta y los errores" do
    v1 = visita(@nelson)
    vista(v1, "Inicio", 300)
    vista(v1, "Calendario", 400)
    vista(visita(@nelson), "Chat", 140)
    evento(v1, "Petición", { ruta: "/chat", estado: 500 })
    anonima = visita
    evento(anonima, "Petición", { ruta: "/invitacion", estado: 200, invitado_id: @david.id })
    evento(anonima, "Tiempo en vista", { segundos_visible: 120 })
    vista(visita(@super), "Rastreo", 999)

    resumen = ResumenRastreo.new(Time.zone.today)
    assert_equal "Rastreo de hoy: 2 personas, 1 error", resumen.titulo
    assert_equal ["Nelson: 2 visitas, 14 min; llegó a Inicio, Calendario y Chat.",
                  "David: abrió la invitación, no la aceptó; 2 min.",
                  "Avisos activados: 0 de 1. Les faltan a Nelson.",
                  "Sin entrar: Hernán (invitación pendiente).",
                  "1 error: 500 en /chat (Nelson)."], resumen.lineas
  end

  test "cuenta quién tiene los avisos activados" do
    vista(visita(@nelson), "Inicio", 60)
    @nelson.push_subscriptions.create!(endpoint: "https://push.example.com/n", p256dh: "clave", auth: "secreto")
    assert_includes ResumenRastreo.new(Time.zone.today).lineas, "Avisos activados: 1 de 1."
  end

  test "lo de otro día no entra, y un día sin nadie queda vacío y no avisa" do
    vieja = visita(@nelson)
    evento(vieja, "$view", { title: "Inicio" }, time: 2.days.ago)
    evento(vieja, "Tiempo en vista", { segundos_visible: 60 }, time: 2.days.ago)
    vista(visita(@super), "Rastreo", 30)
    assert ResumenRastreo.new(Time.zone.today).vacio?, "el superadmin no cuenta y lo de anteayer no es de hoy"
    assert_not ResumenRastreo.new(2.days.ago.to_date).vacio?
    assert_no_difference -> { Notificacion.count } do
      ResumenRastreoJob.perform_now
    end
  end

  test "el job avisa solo a los superadmins y el aviso abre /rastreo" do
    vista(visita(@nelson), "Inicio", 45)
    assert_difference -> { Notificacion.count }, 1 do
      ResumenRastreoJob.perform_now
    end
    aviso = Notificacion.last
    assert_equal @super, aviso.user
    assert_equal "rastreo", aviso.tipo
    assert_equal "/rastreo", aviso.url
    assert_equal "Rastreo de hoy: 1 persona, sin errores", aviso.titulo
    assert_includes aviso.cuerpo, "Nelson: 1 visita, 45 s; llegó a Inicio."
  end

  test "las cuentas de RASTREO_SIN_CONTAR (hneira, sin la variable) no cuentan" do
    hector = vecino("Hector")
    hector.update_columns(username: "hneira")
    vista(visita(hector), "Inicio", 300)
    assert ResumenRastreo.new(Time.zone.today).vacio?

    vista(visita(@nelson), "Inicio", 60)
    assert_equal ["Nelson"], ResumenRastreo.new(Time.zone.today).personas.map { _1[:user].nombre }
  end
end
