require "test_helper"

# Un evento del calendario (con sus fechas siguientes, si es de una serie) pasa a ser reunión de un grupo que se
# convoca: conserva las respuestas, sale de la serie del calendario y no avisa a nadie.
class EventoAReunionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @admin = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio = persona("Sara", @suv)
    @otro_socio = persona("Simón", @suv)
    @vecino_grupo = persona("Vera", @clasicos)
  end

  test "el admin lleva una fecha de la serie y las siguientes como encuentros de su grupo" do
    # Como en producción: la serie está en la raíz y la creó el admin de un grupo.
    maestro = evento(@mercedes, titulo: "Encuentro Ruta semanal", recurrencia_tipo: "semanal", recurrencia_intervalo: 1,
                                recurrencia_fin: "ocurrencias", recurrencia_count: 5)
    fechas = [maestro, *maestro.instancias.ordenados]
    assert_equal 5, fechas.size
    EventoConfirmacion.create!(calendario_evento: fechas[2], user: @socio, estado: :confirmado)
    EventoConfirmacion.create!(calendario_evento: fechas[3], user: @otro_socio, estado: :rechazado)

    sign_in @admin
    get "/t/#{@mercedes.slug}/calendario/#{fechas[2].id}"
    assert_includes response.body, "Llevar como encuentro (esta y las 2 siguientes)"

    assert_no_difference -> { Notificacion.count } do
      perform_enqueued_jobs do
        post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: fechas[2].id, logia_id: @suv.id }
      end
    end
    reuniones = Reunion.where(calendario_evento_id: fechas.map(&:id)).order(:inicio).to_a
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones/#{reuniones.first.id}"
    assert_equal fechas[2..].map(&:id), reuniones.map(&:calendario_evento_id), "solo esta y las siguientes"
    assert reuniones.all? { _1.logia == @suv && _1.user == @admin && _1.convocada? }
    assert_equal 1, reuniones.map(&:serie).uniq.compact.size
    assert_equal "Ruta semanal", reuniones.first.titulo
    assert_equal "Encuentro: Ruta semanal", fechas[2].reload.titulo
    assert_equal @suv, fechas[2].logia
    assert_equal "confirmado", reuniones[0].respuesta_de(@socio)
    assert_equal "rechazado", reuniones[1].respuesta_de(@otro_socio)

    # Salen de la serie, que termina el día anterior; las fechas anteriores siguen en ella.
    assert fechas[2..].all? { _1.reload.serie_id.nil? && !_1.recurrente? }
    maestro.reload
    assert_equal ["fecha", fechas[2].inicio.to_date - 1], [maestro.recurrencia_fin, maestro.recurrencia_hasta]
    assert_equal maestro.id, fechas[1].reload.serie_id

    # Editar la serie entera ya no borra las fechas de los encuentros.
    maestro.regenerar_instancias!
    assert_equal 1, maestro.instancias.count
    assert_equal reuniones.size, CalendarioEvento.where(id: reuniones.map(&:calendario_evento_id)).count
    get "/t/#{@mercedes.slug}/calendario/#{fechas[2].id}"
    assert_includes response.body, "/reuniones/#{reuniones.first.id}"
    assert_not_includes response.body, "Llevar como"
  end

  test "un evento suelto pasa solo, y su recordatorio pendiente lo manda la reunión" do
    suelto = evento(@suv, inicio: 10.hours.from_now)
    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @suv.id }
    reunion = suelto.reload.reunion
    assert_nil reunion.serie
    assert_nil reunion.recordatorio_enviado_at

    perform_enqueued_jobs do
      RecordatorioEventosJob.perform_now
      RecordatorioReunionesJob.perform_now
    end
    assert_equal 0, Notificacion.where(tipo: "evento_recordatorio").count
    assert_equal [@socio.id, @otro_socio.id, @admin.id].sort, Notificacion.where(tipo: "reunion_recordatorio").pluck(:user_id).sort
  end

  test "ni un socio, ni en un grupo que no convoca, ni un evento ajeno, ni dos veces" do
    suelto = evento(@suv)
    sign_in @socio
    get "/t/#{@mercedes.slug}/calendario/#{suelto.id}"
    assert_not_includes response.body, "Llevar como"
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @suv.id }
    assert_response :not_found

    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @clasicos.id }
    assert_response :not_found
    de_otro = evento(@mercedes, user: @vecino_grupo)
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: de_otro.id, logia_id: @suv.id }
    assert_response :not_found
    ajena = logia("Barrio ajeno", categoria: @club)
    de_otra_comunidad = evento(ajena, user: persona("Abel", ajena))
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: de_otra_comunidad.id, logia_id: @suv.id }
    assert_response :not_found
    assert_equal 0, Reunion.count

    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @suv.id }
    assert_equal 1, Reunion.count
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @suv.id }
    assert_response :not_found
    assert_equal 1, Reunion.count
  end

  test "el panel de quien gestiona lleva al evento para pasarlo a reunión; el de un socio no" do
    suelto = evento(@suv)
    sign_in @admin
    get "/t/#{@mercedes.slug}/dashboard"
    assert_includes response.body, "Llevar como encuentro (orden del día, quórum y QR)"
    assert_includes response.body, "/calendario/#{suelto.id}"

    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_includes response.body, "/calendario/#{suelto.id}"
    assert_not_includes response.body, "Llevar como"

    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: suelto.id, logia_id: @suv.id }
    get "/t/#{@mercedes.slug}/dashboard"
    assert_not_includes response.body, "Llevar como"
  end

  test "una serie demasiado larga no se lleva" do
    diaria = evento(@suv, recurrencia_tipo: "diaria", recurrencia_intervalo: 1, recurrencia_fin: "ocurrencias",
                          recurrencia_count: Reunion::MAX_DESDE_EVENTOS + 5)
    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones/desde_evento", params: { evento_id: diaria.id, logia_id: @suv.id }
    assert_redirected_to "/t/#{@mercedes.slug}/calendario/#{diaria.id}"
    assert_equal 0, Reunion.count
    assert_equal Reunion::MAX_DESDE_EVENTOS + 4, diaria.reload.instancias.count
  end

  private

  def evento(logia, user: @admin, inicio: 3.days.from_now.change(hour: 18), **attrs)
    CalendarioEvento.create!(logia: logia, user: user, titulo: "Encuentro de prueba", inicio: inicio,
                             fin: inicio + 2.hours, ubicacion: "Club de campo", **attrs)
  end

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
