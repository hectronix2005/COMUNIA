require "test_helper"

# El monitor: /salud para el chequeo externo de GitHub y el registro de errores 500 (ErrorApp) con su aviso
# al superadmin.
class MonitorTest < ActionDispatch::IntegrationTest
  setup do
    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    @super = User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                          password: "password123", rol_ref: rol)
  end

  test "salud responde ok si llega a la base, y 503 sin detalle si no" do
    get "/salud"
    assert_response :ok
    assert_equal "ok", response.body

    sustituir(ActiveRecord::Base, :with_connection, -> { raise ActiveRecord::ConnectionNotEstablished, "sin base" }) do
      get "/salud"
    end
    assert_response :service_unavailable
    assert_equal "error", response.body
  end

  test "un error no controlado en una petición queda registrado con su controlador" do
    sign_in @super
    sustituir(Logia, :tenants_raiz, -> { raise "fallo de prueba" }) do
      assert_raises(RuntimeError) { get "/tenants" }
    end
    error = ErrorApp.sole
    assert_equal "RuntimeError", error.clase
    assert_equal "TenantsController#index", error.origen
    assert_predicate error.traza, :present?
  end

  test "un error de rails runner no se registra ni avisa" do
    assert_no_difference -> { ErrorApp.count } do
      Rails.error.report(lanzado(NameError, "consulta mal escrita"), handled: false, source: "application.runner.railties")
    end
  end

  test "cada huella avisa la primera vez y al volver tras darla por resuelta" do
    reportar = -> { Rails.error.report(lanzado(RuntimeError, "boom"), handled: false) }

    assert_difference -> { @super.notificaciones.where(tipo: "error_app").count }, 1 do
      2.times { reportar.call }
    end
    error = ErrorApp.sole
    assert_equal 2, error.veces

    error.update!(resuelto_at: Time.current)
    assert_difference -> { @super.notificaciones.where(tipo: "error_app").count }, 1 do
      reportar.call
    end
    assert_nil error.reload.resuelto_at
    assert_equal 3, error.veces
  end

  test "no se registran los errores controlados ni los que Rails convierte en 404" do
    Rails.error.report(lanzado(RuntimeError, "controlado"), handled: true)
    Rails.error.report(lanzado(ActiveRecord::RecordNotFound, "no está"), handled: false)
    assert_equal 0, ErrorApp.count
  end

  test "de DENUNCIAPP no se guarda el mensaje del error" do
    ErrorApp.registrar!(lanzado(RuntimeError, "texto de la denuncia"), origen: "Denuncias::ApiController#create")
    assert_nil ErrorApp.sole.mensaje
  end

  test "la página de errores es solo del superadmin" do
    Rails.error.report(lanzado(RuntimeError, "boom"), handled: false)
    error = ErrorApp.sole

    sign_in @super
    get "/errores"
    assert_response :ok
    assert_match "RuntimeError", response.body
    patch "/errores/#{error.id}/resolver"
    assert error.reload.resuelto_at

    logia = Logia.create!(nombre: "Logia M", slug: "logia-m-#{SecureRandom.hex(3)}", codigo: "LM#{SecureRandom.hex(2).upcase}")
    miembro = User.create!(nombre: "M", apellido: "P", email: "m_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                           logia: logia, rol_ref: Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" })
    sign_in miembro
    get "/errores"
    assert_redirected_to root_path
    get "/errores/#{error.id}"
    assert_redirected_to root_path
  end

  private

  # Minitest 6 ya no trae stub.
  def sustituir(objeto, metodo, impl)
    original = objeto.method(metodo)
    objeto.define_singleton_method(metodo) { |*| impl.call }
    yield
  ensure
    objeto.singleton_class.send(:remove_method, metodo)
    objeto.define_singleton_method(metodo, original) unless objeto.respond_to?(metodo)
  end

  def lanzado(clase, mensaje)
    raise clase, mensaje
  rescue clase => e
    e
  end
end
