require "test_helper"

# Reuniones: se convocan en un grupo (o en la raíz, para toda la comunidad), se confirman, se registra la
# asistencia y se publica el acta. Solo las ven quienes están convocados y quienes las gestionan; nada sale de
# la organización.
class ReunionesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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
    @vecino_grupo, @ficha_vecino = persona("Vera", @clasicos)
    @ajeno, @ficha_ajeno = persona("Abel", logia("Barrio ajeno", categoria: @club))
  end

  test "el admin convoca, se crea el evento y solo se avisa a los convocados" do
    sign_in @admin
    get "/t/#{@mercedes.slug}/reuniones/new"
    assert_response :ok
    assert_match "Convocar encuentro", response.body

    perform_enqueued_jobs do
      post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id) }
    end
    reunion = Reunion.order(:id).last
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    assert_equal @admin, reunion.user
    assert_equal "Encuentro: Ruta a La Calera", reunion.calendario_evento.titulo
    assert_equal "Club de campo", reunion.calendario_evento.ubicacion

    avisados = Notificacion.where(tipo: "reunion_convocatoria").pluck(:user_id)
    assert_equal [@socio.id, @otro_socio.id].sort, avisados.sort, "ni el que convoca, ni otro grupo, ni otra comunidad"
  end

  test "no se convoca en un grupo que no se gestiona ni lo hace un socio raso" do
    sign_in @admin
    assert_no_difference -> { Reunion.count } do
      post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @clasicos.id) }
    end
    assert_response :not_found

    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones/new"
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones"
    assert_no_difference -> { Reunion.count } do
      post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id) }
    end

    reunion = convocar(@suv)
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/asistencia"
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/cancelar"
    assert reunion.reload.convocada?
  end

  test "un cargo vigente convoca en su grupo" do
    cargo = Cargo.create!(logia: @suv, nombre: "Secretaría")
    MiembroCargo.create!(miembro: @ficha_socio, cargo: cargo, desde: Date.current)
    sign_in @socio
    post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id) }
    assert_equal @suv, Reunion.order(:id).last.logia
  end

  test "cada uno ve las de su grupo y las de toda la comunidad, nunca las de otro grupo u otra comunidad" do
    del_grupo = convocar(@suv)
    de_todos = convocar(@mercedes)
    de_otro_grupo = convocar(@clasicos)

    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones"
    assert_match del_grupo.titulo, response.body
    assert_match de_todos.titulo, response.body
    assert_no_match de_otro_grupo.titulo, response.body
    get "/t/#{@mercedes.slug}/reuniones/#{de_otro_grupo.id}"
    assert_response :not_found

    sign_in @ajeno
    get "/t/#{@mercedes.slug}/reuniones/#{de_todos.id}"
    assert_redirected_to "/dashboard", "a otra comunidad no se entra"
    get "/t/#{@ajeno.logia.slug}/reuniones/#{de_todos.id}"
    assert_response :not_found
  end

  test "a la de toda la comunidad se convoca a todos sus grupos" do
    reunion = convocar(@mercedes)
    assert_equal [@ficha_socio, @ficha_otro, @ficha_vecino].map(&:id).sort, (reunion.convocados.ids - [@admin.miembro.id]).sort
    assert_not_includes reunion.convocados, @ficha_ajeno
  end

  test "confirmar en la reunión es confirmar en el calendario y aparece en el panel" do
    reunion = convocar(@suv)
    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_match "Lo próximo · Encuentro", response.body
    assert_match reunion.titulo, response.body

    post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/responder", params: { estado: "confirmado" }
    assert_equal "confirmado", reunion.calendario_evento.evento_confirmaciones.find_by(user: @socio).estado
    post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/responder", params: { estado: "pendiente" }
    assert_response :unprocessable_entity
  end

  test "la asistencia solo cuenta a los convocados y da el quórum" do
    reunion = convocar(@suv)
    sign_in @admin
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/asistencia"
    assert_response :ok
    assert_match @socio.nombre_completo, response.body
    assert_no_match @vecino_grupo.nombre_completo, response.body
    post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/asistencia",
         params: { miembro_ids: [@ficha_socio.id, @ficha_vecino.id, @ficha_ajeno.id] }
    reunion.reload
    assert reunion.celebrada?
    assert_equal [@ficha_socio.id], reunion.reunion_asistencias.pluck(:miembro_id), "los de otro grupo o comunidad se ignoran"
    assert_equal 33, reunion.quorum, "1 de 3 convocados"

    post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/asistencia", params: { miembro_ids: [@ficha_otro.id] }
    assert_equal [@ficha_otro.id], reunion.reunion_asistencias.pluck(:miembro_id), "se puede corregir"
  end

  test "el acta es un borrador hasta que se publica, y al publicarla se avisa" do
    reunion = convocar(@suv)
    reunion.update!(estado: :celebrada, acta: "Se aprobó la ruta de diciembre.")

    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    assert_no_match "Se aprobó la ruta", response.body

    sign_in @admin
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/edit"
    assert_match "reunion[acta]", response.body
    patch "/t/#{@mercedes.slug}/reuniones/#{reunion.id}", params: { reunion: { acta: "Se aprobó la ruta de diciembre y la cuota." } }
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    assert_match "Borrador", response.body
    perform_enqueued_jobs { post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/publicar_acta" }
    assert reunion.reload.acta_publicada?
    assert_equal 2, Notificacion.where(tipo: "reunion_acta").count

    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    assert_match "y la cuota", response.body
  end

  test "si cambia la fecha se avisa, se mueve el evento y vuelve a tocar recordatorio" do
    reunion = convocar(@suv)
    reunion.update_column(:recordatorio_enviado_at, Time.current)
    nueva = 5.days.from_now.change(hour: 18, min: 0, sec: 0)
    sign_in @admin
    perform_enqueued_jobs do
      patch "/t/#{@mercedes.slug}/reuniones/#{reunion.id}", params: { reunion: { inicio: nueva, fin: nueva + 1.hour } }
    end
    reunion.reload
    assert_equal nueva, reunion.calendario_evento.inicio
    assert_nil reunion.recordatorio_enviado_at
    assert_equal 2, Notificacion.where(tipo: "reunion_cambio").count
  end

  test "cancelar quita el evento del calendario y avisa" do
    reunion = convocar(@suv)
    evento_id = reunion.calendario_evento_id
    sign_in @admin
    perform_enqueued_jobs { post "/t/#{@mercedes.slug}/reuniones/#{reunion.id}/cancelar" }
    assert reunion.reload.cancelada?
    assert_not CalendarioEvento.exists?(evento_id)
    assert_equal 2, Notificacion.where(tipo: "reunion_cancelada").count
  end

  test "el recordatorio sale una vez, el día antes, y no a quien dijo que no va" do
    reunion = convocar(@suv, inicio: 20.hours.from_now)
    reunion.update_column(:recordatorio_enviado_at, nil)
    lejana = convocar(@suv, inicio: 3.days.from_now)
    reunion.calendario_evento.evento_confirmaciones.create!(user: @otro_socio, estado: :rechazado)

    2.times { RecordatorioReunionesJob.perform_now }
    avisados = Notificacion.where(tipo: "reunion_recordatorio").pluck(:user_id)
    assert_equal [@admin.id, @socio.id].sort, avisados.sort
    assert_nil lejana.reload.recordatorio_enviado_at
  end

  test "si la categoría no usa reuniones, desaparecen" do
    @club.update!(modulos: %w[tesoreria])
    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones"
    assert_redirected_to "/t/#{@mercedes.slug}/dashboard"
    get "/t/#{@mercedes.slug}/dashboard"
    assert_no_match "/reuniones", response.body
  end

  test "votación: abre quien gestiona, votan los convocados una vez y se ven los totales al cerrar" do
    reunion = convocar(@suv)
    base = "/t/#{@mercedes.slug}/reuniones/#{reunion.id}"
    sign_in @socio
    post "#{base}/votaciones", params: { reunion_votacion: { pregunta: "¿Intruso?" } }
    assert_equal 0, reunion.reunion_votaciones.count, "un socio raso no abre votaciones"

    sign_in @admin
    perform_enqueued_jobs do
      post "#{base}/votaciones", params: { reunion_votacion: { pregunta: "¿Se aprueba la ruta de diciembre?", secreta: "1" } }
    end
    votacion = reunion.reunion_votaciones.last
    assert votacion.secreta?
    assert_equal 2, Notificacion.where(tipo: "reunion_votacion").count

    sign_in @socio
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "no" }
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "si" }
    sign_in @otro_socio
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "si" }
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "trampa" }
    assert_response :unprocessable_entity
    sign_in @vecino_grupo
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "no" }
    assert_response :not_found, "otro grupo no ve la reunión ni vota"

    assert_equal({ "si" => 2, "no" => 0, "abstencion" => 0 }, votacion.totales, "un voto por persona, el último cuenta")
    sign_in @socio
    get base
    assert_match "2 votos", response.body
    assert_no_match "<strong>2</strong> sí", response.body, "mientras está abierta no se ven los totales"

    sign_in @admin
    post "#{base}/votaciones/#{votacion.id}/cerrar"
    assert votacion.reload.cerrada?
    assert votacion.aprobada?
    sign_in @otro_socio
    post "#{base}/votaciones/#{votacion.id}/votar", params: { opcion: "no" }
    assert_equal 2, votacion.totales["si"], "cerrada no admite votos"
    get base
    assert_match "Aprobada", response.body
    assert_no_match @socio.nombre_corto, response.body.split("Votaciones").last, "secreta: no se ve quién votó qué"
  end

  test "el plural sale en español" do
    assert_equal %w[Reuniones Tenidas Encuentros Asambleas Sesiones Peces],
                 %w[Reunión Tenida Encuentro Asamblea Sesión Pez].map { Logia.plural(_1) }
  end

  test "una serie semanal crea todas las fechas con un solo aviso y cada una su evento" do
    sign_in @admin
    perform_enqueued_jobs do
      post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id), repetir: "semanal", veces: "4" }
    end
    serie = Reunion.where(logia: @suv).order(:inicio).to_a
    assert_equal 4, serie.size
    assert_equal 1, serie.map(&:serie).uniq.size
    assert_equal [7.days] * 3, serie.each_cons(2).map { (_2.inicio - _1.inicio).seconds }
    assert serie.all? { _1.fin - _1.inicio == 2.hours }
    assert_equal 4, serie.map(&:calendario_evento_id).compact.uniq.size
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones/#{serie.first.id}"

    avisos = Notificacion.where(tipo: "reunion_serie")
    assert_equal [@socio.id, @otro_socio.id].sort, avisos.pluck(:user_id).sort, "un aviso por persona, no uno por fecha"
    assert_match "4 fechas, cada semana", avisos.first.cuerpo
    assert_equal 0, Notificacion.where(tipo: "reunion_convocatoria").count

    get "/t/#{@mercedes.slug}/reuniones"
    assert_equal 1, response.body.scan("Ruta a La Calera").size, "en la lista, solo la fecha más cercana de la serie"

    get "/t/#{@mercedes.slug}/reuniones/#{serie.first.id}"
    assert_match "Se repite", response.body
    assert_match "Cancelar esta y las 3 siguientes", response.body
  end

  test "cancelar esta y las siguientes deja las anteriores y avisa una vez" do
    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id), repetir: "quincenal", veces: "5" }
    serie = Reunion.where(logia: @suv).order(:inicio).to_a
    assert_equal 14.days, serie[1].inicio - serie[0].inicio

    perform_enqueued_jobs do
      post "/t/#{@mercedes.slug}/reuniones/#{serie[2].id}/cancelar", params: { alcance: "siguientes" }
    end
    assert_equal %w[convocada convocada cancelada cancelada cancelada], serie.map { _1.reload.estado }
    assert_nil serie[3].calendario_evento_id
    assert_equal 2, Notificacion.where(tipo: "reunion_serie_cancelada").count
    assert_match "Se cancelaron 3 fechas", Notificacion.find_by(tipo: "reunion_serie_cancelada").titulo

    post "/t/#{@mercedes.slug}/reuniones/#{serie[0].id}/cancelar"
    assert serie[0].reload.cancelada?
    assert serie[1].reload.convocada?, "sin alcance solo se cancela esa fecha"
  end

  test "una serie mensual cae el mismo día de la semana; si era el quinto, el último del mes" do
    segundo_martes = Time.zone.local(2026, 11, 10, 19)
    assert_equal ["2026-11-10", "2026-12-08", "2027-01-12"],
                 Reunion.fechas_de_serie(segundo_martes, "mensual", 3).map { _1.to_date.iso8601 }
    quinto_jueves = Time.zone.local(2026, 10, 29, 19)
    assert_equal ["2026-10-29", "2026-11-26", "2026-12-31"],
                 Reunion.fechas_de_serie(quinto_jueves, "mensual", 3).map { _1.to_date.iso8601 }
    assert Reunion.fechas_de_serie(quinto_jueves, "mensual", 3).all? { _1.hour == 19 }
  end

  test "una repetición desconocida o un número fuera de rango no se cuela" do
    sign_in @admin
    post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id), repetir: "diaria", veces: "500" }
    assert_equal 1, Reunion.where(logia: @suv).count
    post "/t/#{@mercedes.slug}/reuniones", params: { reunion: datos(logia_id: @suv.id), repetir: "semanal", veces: "500" }
    assert_equal 1 + Reunion::MAX_FECHAS, Reunion.where(logia: @suv).count
  end

  private

  def datos(**extra)
    inicio = 3.days.from_now.change(hour: 19)
    { titulo: "Ruta a La Calera", inicio: inicio, fin: inicio + 2.hours, lugar: "Club de campo",
      orden_del_dia: "1. Ruta\n2. Cuotas" }.merge(extra)
  end

  def convocar(logia, inicio: 3.days.from_now)
    Reunion.create!(logia: logia, user: @admin, titulo: "Reunión #{SecureRandom.hex(3)}", inicio: inicio, fin: inicio + 2.hours)
  end

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
