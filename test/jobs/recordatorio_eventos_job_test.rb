require "test_helper"

# El recordatorio de los eventos del calendario (una tenida, un paseo del club): sale una vez, en las 24 h
# previas, a los miembros activos del grupo del evento (o de toda la comunidad si es de la raíz), menos a quien
# dijo que no va. Los eventos de una reunión los recuerda la reunión.
class RecordatorioEventosJobTest < ActiveSupport::TestCase
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @mercedes = logia("Mercedes")
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @sara = persona("Sara", @suv)
    @pablo = persona("Pablo", @suv)
    @carla = persona("Carla", @clasicos)
    @ido = persona("Ido", @suv, estado: :quite, estado_desde: Date.yesterday)
    @ajeno = persona("Ajeno", logia("Barrio ajeno"))
  end

  test "sale una vez a su grupo, no a otro grupo, ni a quien se fue, ni a quien dijo que no" do
    lavado = evento(@suv, "Lavado SUV", 20.hours.from_now, ubicacion: "Usaquén")
    lavado.evento_confirmaciones.create!(user: @pablo, estado: :rechazado)
    lejano = evento(@suv, "Asado", 3.days.from_now)

    2.times { RecordatorioEventosJob.perform_now }

    avisos = Notificacion.where(tipo: "evento_recordatorio")
    assert_equal [@sara.id], avisos.pluck(:user_id)
    aviso = avisos.first
    assert_match(/\A(Hoy|Mañana): Lavado SUV\z/, aviso.titulo)
    assert_match "Usaquén. ¿Vas a ir?", aviso.cuerpo
    assert_equal "/calendario/#{lavado.id}", aviso.url
    assert lavado.reload.recordatorio_enviado_at
    assert_nil lejano.reload.recordatorio_enviado_at
  end

  test "lo de la raíz llega a todos sus grupos, y nunca a otra comunidad" do
    evento(@mercedes, "Ruta a Guatavita", 10.hours.from_now)
    RecordatorioEventosJob.perform_now
    assert_equal [@sara.id, @pablo.id, @carla.id].sort, Notificacion.where(tipo: "evento_recordatorio").pluck(:user_id).sort
  end

  test "el evento de una reunión no se recuerda dos veces" do
    inicio = 10.hours.from_now
    Reunion.create!(logia: @suv, user: @sara, titulo: "Asamblea", inicio: inicio, fin: inicio + 1.hour)
    RecordatorioEventosJob.perform_now
    assert_equal 0, Notificacion.where(tipo: "evento_recordatorio").count
  end

  test "si cambia la fecha, vuelve a tocar" do
    lavado = evento(@suv, "Lavado SUV", 20.hours.from_now)
    RecordatorioEventosJob.perform_now
    lavado.update!(titulo: "Lavado y brillado")
    assert lavado.reload.recordatorio_enviado_at, "cambiar el título no lo reinicia"
    lavado.update!(inicio: 4.days.from_now, fin: 4.days.from_now + 1.hour)
    assert_nil lavado.reload.recordatorio_enviado_at
  end

  private

  def logia(nombre, tenant: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant)
  end

  def evento(logia, titulo, inicio, **attrs)
    CalendarioEvento.create!(logia: logia, user: @sara, titulo: titulo, inicio: inicio, fin: inicio + 1.hour, **attrs)
  end

  def persona(nombre, logia, **attrs)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol_miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4),
                    estado: :activo, **attrs)
    user
  end
end
