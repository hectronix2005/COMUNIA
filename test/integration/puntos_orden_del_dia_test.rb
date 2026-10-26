require "test_helper"

# Puntos para el orden del día: un convocado propone antes de la reunión, quien la gestiona lo incluye (entra en el
# orden del día con su nombre y se le avisa) o lo descarta. Solo ven el punto quien lo propuso y quien gestiona.
class PuntosOrdenDelDiaTest < ActionDispatch::IntegrationTest
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
    @otro_socio, = persona("Simón", @suv)
    @vecino_grupo, = persona("Vera", @clasicos)
    inicio = 2.days.from_now.change(hour: 19)
    @reunion = Reunion.create!(logia: @suv, user: @admin, titulo: "Ruta", inicio: inicio, fin: inicio + 2.hours,
                               orden_del_dia: "1. Cuotas")
    @base = "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"
  end

  test "el socio propone, quien gestiona lo incluye con su nombre y se le avisa" do
    sign_in @socio
    get @base
    assert_includes response.body, "¿Quieres proponer un punto para el orden del día?"
    post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Salida de fin de año" } }
    assert_redirected_to "#{@base}#propuestas"
    propuesta = @reunion.reunion_propuestas.sole
    assert propuesta.pendiente?
    assert_equal @ficha_socio, propuesta.miembro
    assert_equal [@admin.id], Notificacion.where(tipo: "reunion_propuesta").pluck(:user_id)

    sign_in @otro_socio
    get @base
    assert_not_includes response.body, "Salida de fin de año", "otro convocado no ve los puntos ajenos"

    sign_in @admin
    get @base
    assert_includes response.body, "1 por revisar"
    assert_includes response.body, "Propone Sara Prueba"
    post "#{@base}/propuestas/#{propuesta.id}/incluir"
    assert_equal "1. Cuotas\n- Salida de fin de año (propone Sara Prueba)", @reunion.reload.orden_del_dia
    assert_equal @reunion.orden_del_dia, @reunion.calendario_evento.reload.descripcion, "el calendario se actualiza"
    assert propuesta.reload.incluida?
    assert_equal [@socio.id], Notificacion.where(tipo: "reunion_propuesta_incluida").pluck(:user_id)
    post "#{@base}/propuestas/#{propuesta.id}/incluir"
    assert_equal 1, @reunion.reload.orden_del_dia.scan("Salida de fin de año").size, "no se incluye dos veces"

    sign_in @socio
    get @base
    assert_includes response.body, "Incluido"
  end

  test "descartar no avisa, y un socio no incluye ni descarta" do
    propuesta = @reunion.reunion_propuestas.create!(miembro: @ficha_socio, texto: "Cambiar de sede")
    sign_in @otro_socio
    post "#{@base}/propuestas/#{propuesta.id}/incluir"
    post "#{@base}/propuestas/#{propuesta.id}/descartar"
    assert propuesta.reload.pendiente?

    sign_in @admin
    post "#{@base}/propuestas/#{propuesta.id}/descartar"
    assert propuesta.reload.descartada?
    assert_equal "1. Cuotas", @reunion.reload.orden_del_dia
    assert_equal 0, Notificacion.where(tipo: "reunion_propuesta_incluida").count

    sign_in @socio
    get @base
    assert_includes response.body, "No se incluyó"
  end

  test "ni otro grupo, ni otra comunidad, ni más de tres esperando, ni cuando ya empezó o se canceló" do
    sign_in @vecino_grupo
    post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Intruso" } }
    assert_response :not_found
    ajeno, = persona("Abel", logia("Barrio ajeno", categoria: @club))
    sign_in ajeno
    post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Intruso" } }
    assert_redirected_to "/dashboard" # otra comunidad: ni entra al tenant
    assert_equal 0, @reunion.reunion_propuestas.count

    sign_in @socio
    4.times { |i| post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Punto #{i}" } } }
    assert_equal 3, @reunion.reunion_propuestas.count
    post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "x" * 501 } }
    assert_equal 3, @reunion.reunion_propuestas.count

    sign_in @otro_socio
    travel_to(@reunion.inicio + 1.minute) do
      reset! # la sesión de antes caducó por inactividad
      sign_in @otro_socio
      post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Tarde" } }
      get @base
      assert_not_includes response.body, "¿Quieres proponer un punto"
    end
    @reunion.update!(estado: :cancelada)
    post "#{@base}/propuestas", params: { reunion_propuesta: { texto: "Cancelada" } }
    assert_equal 3, @reunion.reunion_propuestas.count
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
