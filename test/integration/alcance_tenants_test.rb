require "test_helper"

# Una organización no ve ni toca lo de otra, aunque cambie el /t/<slug> de la URL o adivine un id: lo ajeno
# da el mismo 404 que lo que no existe. Dentro de la organización, un admin solo gestiona sus logias.
class AlcanceTenantsTest < ActionDispatch::IntegrationTest
  setup do
    @a     = logia("Tenant A")
    @a_hija = logia("Grupo A2", tenant: @a)
    @b     = logia("Tenant B")
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }

    @yo, @mi_ficha = persona("Yo", @a)
    @vecino, @ficha_vecino = persona("Vecino", @a)
    @otro, @ficha_b = persona("Secreto", @b, telefono: "3009998877")
  end

  test "cambiar el tenant de la URL no enseña el de otra organización" do
    %w[directorio chat publicaciones calendario hospitalia negocios dashboard].each do |modulo|
      sign_in @yo
      get "/t/#{@b.slug}/#{modulo}"
      assert_redirected_to "/dashboard", modulo
      follow_redirect!
      follow_redirect! while response.redirect?
      assert_no_match "Secreto", response.body, modulo
    end
  end

  test "un miembro no abre por id nada de otra organización" do
    pub     = Publicacion.create!(user: @otro, logia: @b, contenido: "De B")
    encuesta = Encuesta.new(user: @otro, logia: @b, titulo: "Encuesta B")
    2.times { |i| encuesta.encuesta_opciones.build(texto: "Opción #{i}") }
    encuesta.save!
    mensaje = ChatMensaje.create!(logia: @b, user: @otro, canal: "tenant", contenido: "Hola B")
    evento  = evento_de(@b, @otro)
    anuncio = NegocioAnuncio.create!(logia: @b, user: @otro, titulo: "Anuncio B", tipo: "servicio")
    libro   = BibliotecaLibro.create!(logia: @b, user: @otro, titulo: "Libro B")
    familiar = MiembroFamiliar.create!(miembro: @ficha_b, nombre_completo: "Hijo de B", parentesco: "Hijo")

    [
      [:get,    "/directorio/#{@ficha_b.id}"],
      [:post,   "/publicaciones/#{pub.id}/toggle_like"],
      [:post,   "/publicaciones/#{pub.id}/comentar", { contenido: "x" }],
      [:delete, "/publicaciones/#{pub.id}"],
      [:get,    "/encuestas/#{encuesta.id}"],
      [:post,   "/encuestas/#{encuesta.id}/votar", { opcion_ids: [encuesta.encuesta_opciones.first.id] }],
      [:post,   "/encuestas/#{encuesta.id}/cerrar"],
      [:post,   "/chat/reaccionar", { id: mensaje.id, emoji: "👍" }],
      [:post,   "/chat/marcar_leido", { id: mensaje.id }],
      [:get,    "/calendario/#{evento.id}"],
      [:post,   "/calendario/#{evento.id}/evento_confirmaciones", { estado: "confirmado" }],
      [:get,    "/negocios/#{anuncio.id}"],
      [:post,   "/negocios/#{anuncio.id}/toggle_favorito"],
      [:post,   "/negocios/#{anuncio.id}/reportar", { negocio_reporte: { motivo: "spam" } }],
      [:post,   "/negocios/#{anuncio.id}/iniciar_conversacion", { cuerpo: "hola" }],
      [:get,    "/biblioteca/libros/#{libro.id}"],
      [:get,    "/hospitalia/familiares", { miembro_id: @ficha_b.id }],
      [:post,   "/hospitalia/familiares", { miembro_id: @ficha_b.id, miembro_familiar: { nombre_completo: "X", parentesco: "Otro" } }],
      [:delete, "/hospitalia/familiares/#{familiar.id}"],
      [:post,   "/hospitalia/felicitacion", { miembro_id: @ficha_b.id }]
    ].each { |verbo, ruta, params| assert_no_encontrado(@yo, verbo, ruta, params) }

    assert Publicacion.exists?(pub.id)
    assert encuesta.reload.activa?
    assert_empty mensaje.reload.reacciones
    assert MiembroFamiliar.exists?(familiar.id)
    assert_not ChatMensaje.exists?(destinatario_id: @otro.id)
  end

  test "la familia de un miembro no la ve ni la cambia otro de la misma organización" do
    familiar = MiembroFamiliar.create!(miembro: @ficha_vecino, nombre_completo: "Hija del vecino", parentesco: "Hija")
    assert_no_encontrado(@yo, :get, "/hospitalia/familiares", { miembro_id: @ficha_vecino.id })
    assert_no_encontrado(@yo, :delete, "/hospitalia/familiares/#{familiar.id}")

    sign_in @yo
    get "/hospitalia/familiares", params: { miembro_id: @mi_ficha.id }
    assert_response :ok
  end

  test "el indicador de escribiendo solo va a los canales propios" do
    sign_in @yo
    post "/chat/typing", params: { stream: "chat_tenant_#{@b.id}" }
    assert_response :forbidden
    post "/chat/typing", params: { stream: "chat_dm_#{[@yo.id, @otro.id].sort.join('_')}" }
    assert_response :forbidden
    post "/chat/typing", params: { stream: "chat_tenant_#{@a.id}" }
    assert_response :ok
    post "/chat/typing", params: { stream: "chat_dm_#{[@yo.id, @vecino.id].sort.join('_')}" }
    assert_response :ok
  end

  test "dentro de la organización se ve todo y se confirma asistencia" do
    evento = evento_de(@a_hija, @vecino)
    sign_in @yo
    get "/directorio/#{@ficha_vecino.id}"
    assert_response :ok
    get "/calendario/#{evento.id}"
    assert_response :ok
    post "/calendario/#{evento.id}/evento_confirmaciones", params: { estado: "confirmado" }
    assert_redirected_to "/calendario/#{evento.id}"
    assert evento.evento_confirmaciones.find_by(user: @yo).confirmado?

    # Las vistas que preguntan modera? para enseñar borrar, fijar o cerrar.
    Publicacion.create!(user: @vecino, logia: @a_hija, contenido: "Del grupo")
    encuesta = Encuesta.new(user: @vecino, logia: @a, titulo: "Encuesta A")
    2.times { |i| encuesta.encuesta_opciones.build(texto: "Opción #{i}") }
    encuesta.save!
    anuncio = NegocioAnuncio.create!(logia: @a_hija, user: @vecino, titulo: "Anuncio A", tipo: "servicio")
    [admin_de(@a), @yo].each do |usuario|
      ["/publicaciones", "/encuestas/#{encuesta.id}", "/negocios/#{anuncio.id}"].each do |ruta|
        sign_in usuario
        get ruta
        assert_response :ok, ruta
      end
    end
  end

  test "un admin no abre la administración de otra organización" do
    admin = admin_de(@a)
    periodo = PeriodoCobro.create!(anio: 2090 + rand(9), mes: rand(1..12), monto: 10, fecha_vencimiento: Date.current, creado_por: @otro)
    cobro = Cobro.create!(periodo_cobro: periodo, miembro: @ficha_b, monto: 10)
    pago = Pago.new(cobro: cobro, monto_pagado: 10, fecha_pago: Date.current, metodo_pago: "transferencia")
    pago.save!(validate: false)

    [
      [:get,  "/cobros/#{cobro.id}"],
      [:get,  "/reportes/recibo/#{pago.id}"],
      [:get,  "/logias/#{@b.id}"],
      [:get,  "/logias/#{@b.id}/conceptos"],
      [:get,  "/logias/#{@b.id}/tarifas"],
      [:post, "/miembros/#{@ficha_b.id}/cargos", { miembro_cargo: { desde: Date.current } }]
    ].each { |verbo, ruta, params| assert_no_encontrado(admin, verbo, ruta, params) }

    sign_in admin
    get "/logias/#{@a.id}/conceptos"
    assert_response :ok
  end

  test "un admin modera su organización y no la ajena" do
    admin = admin_de(@a)
    propia = Publicacion.create!(user: @vecino, logia: @a, contenido: "De A")
    ajena  = Publicacion.create!(user: @otro, logia: @b, contenido: "De B")

    assert_no_encontrado(admin, :delete, "/publicaciones/#{ajena.id}")
    sign_in admin
    delete "/publicaciones/#{propia.id}"
    assert_redirected_to "/publicaciones"
    assert_not Publicacion.exists?(propia.id)
  end

  test "hospitalía no apunta recaudos ni gastos a miembros de otra organización" do
    admin = admin_de(@a)
    sign_in admin
    assert_no_difference -> { HospitaliaRecaudo.count + HospitaliaGasto.count } do
      post "/hospitalia/recaudos", params: { hospitalia_recaudo: { concepto: "Cuota", monto: 10, fecha: Date.current, miembro_id: @ficha_b.id } }
      assert_response :unprocessable_entity
      post "/hospitalia/gastos", params: { hospitalia_gasto: { concepto: "Ayuda", monto: 10, fecha: Date.current, beneficiario_id: @ficha_b.id } }
      assert_response :unprocessable_entity
    end
    assert_no_match "Secreto", response.body

    post "/hospitalia/recaudos", params: { hospitalia_recaudo: { concepto: "Cuota", monto: 10, fecha: Date.current, miembro_id: @mi_ficha.id } }
    assert_redirected_to "/hospitalia/recaudos"
    assert_equal @mi_ficha, HospitaliaRecaudo.last.miembro
  end

  test "cambiar el rol en la ficha cambia también el enum rol" do
    admin = admin_de(@a)
    sign_in admin
    patch "/miembros/#{@ficha_vecino.id}/cambiar_rol", params: { rol_codigo: "admin_logia" }
    assert @vecino.reload.admin_logia?
    patch "/miembros/#{@ficha_vecino.id}/cambiar_rol", params: { rol_codigo: "miembro" }
    assert @vecino.reload.miembro?
    assert_equal "miembro", @vecino.rol_ref.codigo
  end

  private

  # Un 404 no guarda la cookie de sesión: se vuelve a entrar antes de cada petición.
  def assert_no_encontrado(usuario, verbo, ruta, params = nil)
    sign_in usuario
    send(verbo, ruta, params: params)
    assert_response :not_found, "#{verbo} #{ruta}"
  end

  def logia(nombre, tenant: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro, **ficha)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref)
    miembro = Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                              cedula: SecureRandom.hex(4), estado: :activo, **ficha)
    [user, miembro]
  end

  def admin_de(logia)
    rol = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    { "cobros" => %w[index show], "reportes" => %w[recibo], "logias" => %w[show gestionar_conceptos],
      "conceptos" => %w[index], "miembros" => %w[index show update] }.each do |recurso, acciones|
      acciones.each do |accion|
        permiso = Permiso.find_or_create_by!(recurso: recurso, accion: accion)
        rol.permisos << permiso unless rol.permisos.include?(permiso)
      end
    end
    persona("Admin", logia, rol_ref: rol).first
  end

  def evento_de(logia, user)
    CalendarioEvento.create!(logia: logia, user: user, titulo: "Evento", inicio: 1.day.from_now, fin: 1.day.from_now + 1.hour)
  end
end
