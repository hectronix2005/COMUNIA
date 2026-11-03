require "test_helper"

# Fase 4 del plan de engagement (ActividadSemanal, /rastreo): por comunidad y semana, quién entró (rastreo bajo
# /t/<slug>) y quién participó, sobre los miembros activos, sin los que no cuenta el rastreo ni la demostración.
class ActividadSemanalTest < ActiveSupport::TestCase
  include DenunciasPrueba

  setup do
    preparar_denuncias
    @ana = vecino("Ana")
    @comunidad = @ana.logia
    @beto = sumar(vecino("Beto"))
    @ciro = sumar(vecino("Ciro"))
    @fede = vecino("Fede") # otra comunidad
    @hneira = sumar(vecino("Héctor"))
    @hneira.update_column(:username, "hneira")
    @grupo = Logia.create!(nombre: "Torre A", slug: "grupo-#{SecureRandom.hex(4)}", codigo: "L#{SecureRandom.hex(3).upcase}", tenant_id: @comunidad.id)
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: 30.days.ago)
  end

  teardown { limpiar_denuncias }

  def sumar(user)
    Miembro.find_by!(user:).update!(logia: @comunidad)
    user.update!(logia: @comunidad)
    user
  end

  def entra(user, slug, time: Time.current)
    visita = Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, user:, started_at: time)
    Ahoy::Event.create!(visit: visita, user:, name: "Petición", properties: { ruta: "/t/#{slug}/dashboard" }, time:)
  end

  def fila(filas, comunidad) = filas.find { _1.comunidad == comunidad }

  test "cuenta quién entró y quién participó cada semana, por comunidad" do
    entra(@ana, @comunidad.slug)
    entra(@beto, @grupo.slug, time: 1.minute.ago)
    entra(@beto, @comunidad.slug, time: 1.week.ago)
    entra(@fede, @comunidad.slug) # no es miembro de esta comunidad
    entra(@hneira, @comunidad.slug) # no cuenta
    entra(@ciro, "otra-cosa")
    Publicacion.create!(logia: @comunidad, user: @ciro, contenido: "Hola")
    Favor.create!(logia: @comunidad, user: @ana, tipo: "pido", titulo: "Una escalera")

    filas = ActividadSemanal.filas
    mia = fila(filas, @comunidad)
    assert_equal 3, mia.miembros, "Ana, Beto y Ciro; hneira no cuenta"
    assert_equal [2, 2], [mia.actual.entraron, mia.actual.participaron]
    assert_equal 1, mia.semanas.second.entraron
    assert_equal 67, mia.porcentaje(2)
    assert mia.en_meta?
    assert_equal 4, mia.semanas.size
    assert_equal 0, fila(filas, @fede.logia).actual.entraron
  end

  test "las semanas de antes del rastreo salen sin dato; la demostración no sale" do
    Ahoy::Visit.delete_all
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: Time.current)
    @fede.logia.update!(slug: Demo::SLUG)
    filas = ActividadSemanal.filas
    assert_nil fila(filas, @comunidad).semanas.last.entraron
    assert_nil fila(filas, @fede.logia)
  end
end
