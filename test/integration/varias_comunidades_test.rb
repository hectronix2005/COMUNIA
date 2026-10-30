require "test_helper"

# Una cuenta, varias comunidades: la misma persona es admin en una y miembro raso en otra. Entrar por /t/<slug>
# vuelve activa esa comunidad, con su rol; la ficha que se ve es la de la comunidad que se mira; una comunidad
# ajena no se abre; y solo el superadmin vincula una cuenta que ya existe.
class VariasComunidadesTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Administrador" }
    %w[index show create update destroy].each { @rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) unless @rol_admin.tiene_permiso?("miembros", _1) }
    @logias = comunidad("Logia Luz", "luz")
    @egresados = comunidad("Egresados Andes", "andes")
    @ajena = comunidad("Club Ajeno", "ajeno")

    @hector = User.create!(nombre: "Hector", apellido: "Neira", email: "hector_#{SecureRandom.hex(3)}@correo.co",
                           password: "password123", logia: @logias, rol_ref: @rol_admin)
    @ficha_logia = ficha(@hector, @logias, cedula: "1032429112", numero: "MBR-015")
    @hector.unir_a_comunidad!(@egresados)
    @ficha_egresado = ficha(@hector, @egresados, cedula: "1032429112", numero: "MBR-015", profesion: "Cohorte 2023-1")
  end

  test "entrar por /t/<slug> activa esa comunidad con su rol, y se vuelve igual" do
    sign_in @hector
    get "/t/andes/dashboard"
    assert_response :success
    @hector.reload
    assert_equal @egresados, @hector.logia
    assert_equal "miembro", @hector.rol_ref.codigo

    # Miembro raso en Egresados: no da de alta a nadie allí.
    get "/t/andes/miembros/new"
    assert_response :redirect
    assert_nil flash[:notice]

    get "/t/luz/miembros/new"
    assert_response :success
    assert_equal "admin_logia", @hector.reload.rol_ref.codigo
    assert_equal @logias, @hector.logia
  end

  test "una comunidad a la que no pertenece no se abre" do
    sign_in @hector
    get "/t/ajeno/dashboard"
    assert_redirected_to "/dashboard"
    assert_equal @logias, @hector.reload.logia
  end

  test "la ficha que se ve es la de la comunidad que se mira, aunque la persona tenga activa otra" do
    otra = User.create!(nombre: "Ana", apellido: "Andes", email: "ana_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @egresados, rol_ref: @rol_miembro)
    ficha(otra, @egresados, cedula: "55", numero: "MBR-001")
    assert_equal @ficha_logia, @hector.miembro

    sign_in otra
    get "/t/andes/directorio/#{@ficha_egresado.id}"
    assert_response :success
    assert_includes response.body, "Cohorte 2023-1"

    Current.set(organizacion: @egresados) { assert_equal @ficha_egresado, User.find(@hector.id).miembro }
    Current.set(organizacion: @logias) { assert_equal @ficha_logia, User.find(@hector.id).miembro }
  end

  test "el menú ofrece cambiar de comunidad" do
    sign_in @hector
    get "/t/luz/dashboard"
    assert_response :success
    assert_includes response.body, "Mis comunidades"
    assert_includes response.body, %(href="/t/andes/dashboard")
    assert_not_includes response.body, %(href="/t/ajeno/dashboard")
  end

  test "cédula y número son únicos en cada comunidad, y una cédula en dos comunidades es de la misma cuenta" do
    otra = User.create!(nombre: "Eva", apellido: "Otra", email: "eva_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @ajena, rol_ref: @rol_miembro)
    repetida = Miembro.new(user: otra, logia: @ajena, cedula: "1032429112", numero_miembro: "MBR-015", estado: :activo)
    assert_not repetida.valid?
    assert_match "pide al superadmin", repetida.errors[:cedula].to_sentence
    assert_empty repetida.errors[:numero_miembro]

    otra_en_luz = Miembro.new(user: otra, logia: @logias, cedula: "999", numero_miembro: "MBR-015", estado: :activo)
    assert_not otra_en_luz.valid?
    assert otra_en_luz.errors[:numero_miembro].any?

    segunda = Miembro.new(user: @hector, logia: @egresados, cedula: "1032429112", numero_miembro: "MBR-099", estado: :activo)
    assert_not segunda.valid?
    assert segunda.errors[:user_id].any?
  end

  test "el superadmin vincula una cuenta existente; un admin de comunidad no" do
    superadmin = User.create!(nombre: "Super", apellido: "Admin", email: "super_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                              rol_ref: Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Superadmin" })
    sign_in superadmin
    assert_difference -> { Miembro.count } => 1, -> { User.count } => 0 do
      post "/miembros", params: { miembro: { logia_id: @ajena.id, cedula: "1032429112", numero_miembro: "A-1",
                                             user_attributes: { nombre: "X", apellido: "Y", email: @hector.email.upcase, password: "" } } }
    end
    assert_equal "Cuenta existente vinculada a esta comunidad.", flash[:notice]
    assert @hector.reload.pertenece_a?(@ajena)
    assert_equal @logias, @hector.logia, "la comunidad activa no cambia"
    assert_equal "Hector", @hector.nombre

    admin = User.create!(nombre: "Rosa", apellido: "Admin", email: "rosa_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @egresados, rol_ref: @rol_admin)
    otra = User.create!(nombre: "Leo", apellido: "Luz", email: "leo_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                        logia: @logias, rol_ref: @rol_miembro)
    sign_in admin
    assert_no_difference -> { Miembro.count } do
      post "/t/andes/miembros", params: { miembro: { cedula: "777", numero_miembro: "B-1",
                                                     user_attributes: { nombre: "Leo", apellido: "Luz", email: otra.email, password: "password123" } } }
    end
    assert_response :unprocessable_entity
    assert_not otra.reload.pertenece_a?(@egresados)
  end

  test "cambiar el rol en una comunidad no toca el de la otra" do
    sign_in User.create!(nombre: "Rosa", apellido: "Admin", email: "rosa_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @egresados, rol_ref: @rol_admin)
    patch "/t/andes/miembros/#{@ficha_egresado.id}/cambiar_rol", params: { rol_codigo: "admin_logia" }
    assert_equal "admin_logia", @hector.pertenencias.find_by(organizacion: @egresados).rol_ref.codigo
    assert_equal "admin_logia", @hector.reload.rol_ref.codigo # sigue activa Logia Luz, donde ya era admin
  end

  test "borrar la ficha de una comunidad solo saca a la persona de esa" do
    @hector.activar_comunidad!(@egresados)
    sign_in User.create!(nombre: "Rosa", apellido: "Admin", email: "rosa_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @egresados, rol_ref: @rol_admin)
    delete "/t/andes/miembros/#{@ficha_egresado.id}"
    @hector.reload
    assert_not @hector.pertenece_a?(@egresados)
    assert_equal @logias, @hector.logia
    assert_equal "admin_logia", @hector.rol_ref.codigo
    assert Miembro.exists?(@ficha_logia.id)
  end

  private

  def comunidad(nombre, slug)
    Logia.create!(nombre: nombre, slug: slug, codigo: slug.upcase)
  end

  def ficha(user, logia, cedula:, numero:, profesion: nil)
    Miembro.create!(user: user, logia: logia, cedula: cedula, numero_miembro: numero, estado: :activo, profesion: profesion)
  end
end
