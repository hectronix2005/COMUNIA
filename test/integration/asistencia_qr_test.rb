require "test_helper"

# Asistencia con QR: quien gestiona la reunión lo enseña y cada convocado lo escanea y pulsa «Estoy aquí». Solo
# vale con el código de esa reunión, desde una hora antes hasta una hora después, y para sus convocados.
class AsistenciaQrTest < ActionDispatch::IntegrationTest
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
    persona("Simón", @suv)
    @vecino_grupo, = persona("Vera", @clasicos)
    @reunion = Reunion.create!(logia: @suv, user: @admin, titulo: "Ruta", inicio: 30.minutes.from_now, fin: 3.hours.from_now)
    @base = "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"
  end

  test "quien gestiona enseña el QR y el socio marca su asistencia con un clic" do
    sign_in @admin
    get "#{@base}/qr"
    assert_response :ok
    assert_includes response.body, "<svg"
    assert_match(/0\s*<span[^>]*>de 3 ya marcaron/, response.body)

    sign_in @socio
    get "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_includes response.body, "Estoy aquí"
    assert_equal 0, @reunion.reunion_asistencias.count, "abrir el enlace no registra nada"

    post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_redirected_to @base
    assert_equal [@ficha_socio.id], @reunion.reunion_asistencias.pluck(:miembro_id)
    assert @reunion.reload.convocada?, "la da por celebrada quien gestiona, al revisar la lista"
    post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_equal 1, @reunion.reunion_asistencias.count
    get "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_includes response.body, "Ya estás en la asistencia"
    get @base
    assert_includes response.body, "Asististe"

    sign_in @admin
    get "#{@base}/asistencia"
    assert_match(/value="#{@ficha_socio.id}"[^>]*checked|checked[^>]*value="#{@ficha_socio.id}"/, response.body)
  end

  test "sin sesión, el QR lleva al login y de vuelta al botón" do
    get "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_response :redirect
    post "/login", params: { user: { email: @socio.username, password: "password123" } }
    assert_redirected_to %r{/reuniones/#{@reunion.id}/presente\?codigo=#{@reunion.codigo_asistencia}\z}
  end

  test "no vale con otro código, fuera de hora, cancelada ni para otro grupo; el QR solo lo ve quien gestiona" do
    sign_in @socio
    get "#{@base}/qr"
    assert_redirected_to @base

    post "#{@base}/presente", params: { codigo: "otro" }
    assert_redirected_to @base
    travel(-2.hours) do
      post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
      assert_redirected_to @base
    end
    travel(4.hours + 5.minutes) do
      reset! # la sesión de antes caducó por inactividad
      sign_in @socio
      post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
      assert_redirected_to @base
    end
    assert_equal 0, @reunion.reunion_asistencias.count

    sign_in @vecino_grupo
    post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_response :not_found

    @reunion.update!(estado: :cancelada)
    sign_in @socio
    post "#{@base}/presente", params: { codigo: @reunion.codigo_asistencia }
    assert_equal 0, @reunion.reunion_asistencias.count
  end

  test "las reuniones de antes reciben su código al enseñar el QR" do
    @reunion.update_column(:codigo_asistencia, nil)
    sign_in @socio
    post "#{@base}/presente", params: { codigo: "" }
    assert_equal 0, @reunion.reunion_asistencias.count

    sign_in @admin
    get "#{@base}/qr"
    assert_equal 24, @reunion.reload.codigo_asistencia.length
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
