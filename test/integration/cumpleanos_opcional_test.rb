require "test_helper"

# Cumpleaños en un edificio o barrio (Logia#cumpleanos?): apagado hasta que lo encienda el admin de la comunidad;
# en las demás categorías sigue siempre. Apagado no sale en el menú, no se abre y no manda avisos.
class CumpleanosOpcionalTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  setup do
    preparar_denuncias
    @barrio = Categoria.find_or_create_by!(nombre: "Barrio")
    @admin = vecino("Adela", rol: "admin_logia")
    rol = @admin.rol_ref
    rol.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: "index") unless rol.tiene_permiso?("miembros", "index")
    @edificio = @admin.logia
    @edificio.update!(categoria: @barrio)
    @vecina = vecino("Vera")
    ficha = Miembro.find_by!(user: @vecina)
    ficha.update!(logia: @edificio)
    @vecina.update!(logia: @edificio)
    ficha.familiares.create!(nombre_completo: "Vera Prueba", parentesco: MiembroFamiliar::PARENTESCOS.first, fecha_nacimiento: Date.current - 30.years)
  end

  teardown { limpiar_denuncias }

  def en(user, ruta) = "/t/#{user.logia.slug}#{ruta}"
  def lleva_a(ruta) = assert_match(%r{/t/[a-z0-9-]+#{Regexp.escape(ruta)}\z}, response.location)

  test "en un edificio está apagado hasta que el admin lo enciende, y lo puede volver a apagar" do
    assert_not @edificio.cumpleanos?

    sign_in @vecina
    get en(@vecina, "/dashboard")
    assert_response :success
    assert_no_match %r{href="[^"]*/hospitalia/cumpleanos"}, response.body
    get en(@vecina, "/hospitalia/cumpleanos")
    lleva_a "/dashboard"
    patch en(@vecina, "/hospitalia/cumpleanos/configuracion"), params: { cumpleanos: { activos: "1" } }
    assert_not @edificio.reload.cumpleanos_activos, "un vecino no lo enciende"
    sign_out :user

    sign_in @admin
    get en(@admin, "/dashboard")
    assert_response :success
    assert_match "Apagado · enciéndelo", response.body
    get en(@admin, "/hospitalia/cumpleanos")
    lleva_a "/hospitalia/cumpleanos/configuracion"
    patch en(@admin, "/hospitalia/cumpleanos/configuracion"), params: { cumpleanos: { activos: "1" } }
    lleva_a "/hospitalia/cumpleanos"
    assert @edificio.reload.cumpleanos?
    sign_out :user

    sign_in @vecina
    get en(@vecina, "/hospitalia/cumpleanos")
    assert_response :success
    assert_match "Vera Prueba", response.body
    sign_out :user

    sign_in @admin
    patch en(@admin, "/hospitalia/cumpleanos/configuracion"), params: { cumpleanos: { activos: "0" } }
    assert_not @edificio.reload.cumpleanos?
  end

  test "apagado no manda avisos; en un club sigue siempre y no hay nada que encender" do
    assert_no_difference -> { Notificacion.where(tipo: %w[cumpleanos cumpleanos_semana], user: @vecina).count } do
      CumpleanosNotificacionJob.perform_now
      CumpleanosSemanaJob.perform_now
    end

    club_admin = vecino("Clara", rol: "admin_logia")
    club_admin.logia.update!(categoria: Categoria.find_or_create_by!(nombre: "Club"))
    assert club_admin.logia.cumpleanos?
    sign_in club_admin
    get en(club_admin, "/hospitalia/cumpleanos")
    assert_response :success
    get en(club_admin, "/hospitalia/cumpleanos/configuracion")
    lleva_a "/dashboard"
  end

  test "se enciende en la comunidad, no en uno de sus grupos" do
    grupo = Logia.new(nombre: "Torre 1", codigo: "T#{SecureRandom.hex(2).upcase}", tenant: @edificio, cumpleanos_activos: true)
    assert_not grupo.valid?
    assert grupo.errors[:cumpleanos_activos].any?
  end
end
