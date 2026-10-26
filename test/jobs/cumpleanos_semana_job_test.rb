require "test_helper"

class CumpleanosSemanaJobTest < ActiveJob::TestCase
  setup do
    @rol = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @a = logia("Tenant A")
    @a_hija = logia("Grupo A2", tenant: @a)
    @b = logia("Tenant B")
  end

  test "cada miembro activo recibe los cumpleaños de su organización en los próximos 7 días" do
    travel_to Date.new(2026, 10, 26) do # lunes
      yo, mi_ficha = persona("Yo", @a)
      _, ficha_hija = persona("Hermano", @a_hija)
      inactivo, = persona("Dormido", @a, estado: :quite, estado_desde: Date.current)
      otro, ficha_b = persona("Ajeno", @b)

      familiar(mi_ficha, "Ana Pérez", Date.new(1990, 10, 28))
      familiar(ficha_hija, "Luis Gómez", Date.new(2001, 11, 1))
      familiar(mi_ficha, "Fuera de semana", Date.new(1980, 11, 2))
      familiar(ficha_b, "Secreto de B", Date.new(1985, 10, 27))

      CumpleanosSemanaJob.perform_now

      aviso = yo.notificaciones.sole
      assert_equal "2 cumpleaños esta semana", aviso.titulo
      assert_match(/\AAna Pérez \(esposa de Yo Prueba\), mié 28; Luis Gómez/, aviso.cuerpo)
      assert_no_match "Fuera de semana", aviso.cuerpo
      assert_no_match "Secreto", aviso.cuerpo
      assert_empty inactivo.notificaciones

      assert_equal "1 cumpleaños esta semana", otro.notificaciones.sole.titulo
    end
  end

  test "el 29 de febrero se celebra el 28 los años no bisiestos" do
    f = MiembroFamiliar.new(fecha_nacimiento: Date.new(2000, 2, 29))
    assert_equal Date.new(2027, 2, 28), f.proximo_cumpleanos(Date.new(2027, 2, 1))
    assert_equal Date.new(2028, 2, 29), f.proximo_cumpleanos(Date.new(2027, 3, 1))
    assert_equal Date.new(2026, 10, 26), MiembroFamiliar.new(fecha_nacimiento: Date.new(1990, 10, 26)).proximo_cumpleanos(Date.new(2026, 10, 26))
  end

  private

  def logia(nombre, tenant: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant)
  end

  def persona(nombre, logia, **ficha)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol)
    miembro = Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                              cedula: SecureRandom.hex(4), estado: :activo, **ficha)
    [user, miembro]
  end

  def familiar(miembro, nombre, fecha)
    MiembroFamiliar.create!(miembro: miembro, nombre_completo: nombre, parentesco: "Esposa", fecha_nacimiento: fecha)
  end
end
