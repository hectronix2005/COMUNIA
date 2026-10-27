require "test_helper"

# El recordatorio de los acuerdos: a quien se encarga, una vez, cuando vence hoy o mañana y aún no está cumplido.
class RecordatorioAcuerdosJobTest < ActiveSupport::TestCase
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro", modulos: %w[reuniones])
    @mercedes = Logia.create!(nombre: "Mercedes", slug: "mercedes-#{SecureRandom.hex(3)}", codigo: "L#{SecureRandom.hex(3).upcase}",
                              categoria: club)
    @sara, @ficha_sara = persona("Sara")
    @pablo, @ficha_pablo = persona("Pablo")
    _, @ficha_ido = persona("Ido")
    @reunion = Reunion.create!(logia: @mercedes, user: @sara, titulo: "Ruta", inicio: 2.days.ago, fin: 2.days.ago + 2.hours)
  end

  test "sale una vez a quien se encarga, si vence hoy o mañana y no está cumplido" do
    bus = acuerdo("Reservar el bus", @ficha_sara, Date.tomorrow)
    acuerdo("Pagar el almuerzo", @ficha_pablo, Date.current)
    acuerdo("Ya hecho", @ficha_pablo, Date.current, cumplido_at: Time.current)
    acuerdo("Para la otra semana", @ficha_sara, 7.days.from_now.to_date)
    acuerdo("Sin fecha", @ficha_sara, nil)
    acuerdo("Sin responsable", nil, Date.tomorrow)
    acuerdo("De quien se fue", @ficha_ido, Date.tomorrow)
    @ficha_ido.update_columns(estado: Miembro.estados[:quite])

    2.times { RecordatorioAcuerdosJob.perform_now }

    avisos = Notificacion.where(tipo: "reunion_acuerdo").order(:titulo)
    assert_equal ["Vence hoy: Pagar el almuerzo", "Vence mañana: Reservar el bus"], avisos.pluck(:titulo)
    assert_equal [@pablo.id, @sara.id], avisos.pluck(:user_id)
    assert_equal "/reuniones/#{@reunion.id}#acuerdos", avisos.last.url
    assert bus.reload.recordatorio_enviado_at
  end

  test "no se recuerda lo de una reunión cancelada" do
    acuerdo("Reservar el bus", @ficha_sara, Date.tomorrow)
    @reunion.update_column(:estado, Reunion.estados[:cancelada])
    RecordatorioAcuerdosJob.perform_now
    assert_equal 0, Notificacion.where(tipo: "reunion_acuerdo").count
  end

  private

  def acuerdo(texto, responsable, vence_el, **attrs)
    @reunion.reunion_acuerdos.create!(texto: texto, responsable: responsable, vence_el: vence_el, **attrs)
  end

  def persona(nombre)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @mercedes, rol_ref: @rol_miembro)
    ficha = Miembro.create!(user: user, logia: @mercedes, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4),
                            estado: :activo)
    [user, ficha]
  end
end
