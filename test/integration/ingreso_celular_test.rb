require "test_helper"

# Ingreso con el celular: la comunidad solo tiene el nombre y el celular de la persona, que entra con él y una
# contraseña temporal. Hasta que elige la suya y da sus datos reales (correo, apellidos, cédula y su programa),
# toda la app la lleva a «Completa tus datos».
class IngresoCelularTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    universidad = Categoria.find_or_create_by!(nombre: "Universidad")
    @andes = Logia.create!(nombre: "Egresados Andes", slug: "andes", codigo: "ANDES", categoria: universidad)
    @clave = User.clave_temporal
    @juan = User.create!(nombre: "Juan Camilo", celular: "+57 310 559 0637", password: @clave, logia: @andes,
                         rol_ref: @rol_miembro, debe_completar_datos: true)
    @ficha = Miembro.create!(user: @juan, logia: @andes, numero_miembro: "MBR-003", estado: :activo,
                             telefono: "3105590637")
  end

  test "la cuenta con celular no necesita correo, apellido ni cédula hasta completar sus datos" do
    assert_equal "3105590637", @juan.celular
    assert_nil @juan.email
    assert_equal "juancamilo", @juan.username
    assert_nil @ficha.cedula

    # Una segunda cuenta sin correo no choca con la primera en el índice único.
    User.create!(nombre: "Ingrid", apellido: "Santana", celular: "3506910000", password: User.clave_temporal,
                 logia: @andes, rol_ref: @rol_miembro, debe_completar_datos: true)

    sin_nada = User.new(nombre: "Ana", apellido: "Sola", password: "password123", logia: @andes)
    assert_not sin_nada.valid?
    assert sin_nada.errors[:email].any?, "sin celular, el correo sigue siendo obligatorio"
    assert_not User.new(nombre: "X", celular: "12345", password: "password123", logia: @andes).valid?
  end

  test "la contraseña temporal se dicta sin confundir letras ni cifras" do
    claves = Array.new(50) { User.clave_temporal }
    assert claves.all? { _1.match?(/\A[a-km-np-z2-9]{10}\z/) }
    assert_equal 50, claves.uniq.size
  end

  test "entra con el celular escrito de cualquier forma, y el resto de la app lo lleva a completar sus datos" do
    ["3105590637", "+57 310 559 0637", "310-559-0637"].each do |login|
      post "/login", params: { user: { email: login, password: @clave } }
      assert_redirected_to "/dashboard", login
      follow_redirect!
      assert_redirected_to "/completa-tus-datos"
      delete "/logout"
    end

    post "/login", params: { user: { email: "3105590637", password: "otra-clave-mala" } }
    assert_response :unprocessable_entity

    post "/login", params: { user: { email: "juancamilo", password: @clave } }
    get "/t/andes/miembros"
    assert_redirected_to "/t/andes/completa-tus-datos"
    get "/completa-tus-datos"
    assert_response :success
    assert_includes response.body, "Programa y cohorte"
    assert_not_includes response.body, "<nav", "sin menú: no hay adónde ir hasta completar"
  end

  test "completar los datos exige todos, y la contraseña no puede ser la temporal" do
    sign_in @juan
    patch "/completa-tus-datos", params: { user: { nombre: "Juan Camilo", apellido: "", email: "", cedula: "", programa: "",
                                                   password: @clave, password_confirmation: @clave } }
    assert_response :unprocessable_entity
    ["Apellido no puede estar en blanco", "Correo electrónico no puede estar en blanco", "Cédula no puede estar en blanco",
     "Programa y cohorte no puede estar en blanco", "distinta de la temporal"].each { assert_includes response.body, _1 }
    assert @juan.reload.debe_completar_datos?

    otra = User.create!(nombre: "Eva", apellido: "Otra", email: "eva_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                        logia: @andes, rol_ref: @rol_miembro)
    Miembro.create!(user: otra, logia: @andes, numero_miembro: "MBR-009", cedula: "80123456", estado: :activo)
    patch "/completa-tus-datos", params: { user: datos_completos(cedula: "80123456") }
    assert_response :unprocessable_entity
    assert_includes response.body, "Cédula ya está en uso"
    assert @juan.reload.debe_completar_datos?
  end

  test "al completar sus datos sigue dentro, con su contraseña nueva y su ficha al día" do
    sign_in @juan
    patch "/completa-tus-datos", params: { user: datos_completos }
    assert_redirected_to "/dashboard"
    get "/t/andes/dashboard"
    assert_response :success, "sigue con la sesión abierta tras cambiar la contraseña"

    @juan.reload
    assert_not @juan.debe_completar_datos?
    assert_equal "Gómez Ruiz", @juan.apellido
    assert_equal "juan@correo.co", @juan.email
    assert @juan.valid_password?("mi-clave-nueva-2026")
    assert_not @juan.valid_password?(@clave)
    @ficha.reload
    assert_equal "1020304050", @ficha.cedula
    assert_equal "Ingeniería de Sistemas - Cohorte 2015", @ficha.bio

    get "/completa-tus-datos"
    assert_redirected_to "/dashboard"
    delete "/logout"
    post "/login", params: { user: { email: "juan@correo.co", password: "mi-clave-nueva-2026" } }
    assert_redirected_to "/dashboard"
  end

  private

  def datos_completos(**cambios)
    { nombre: "Juan Camilo", apellido: "Gómez Ruiz", email: "Juan@correo.co", cedula: "1020304050",
      programa: "Ingeniería de Sistemas - Cohorte 2015", password: "mi-clave-nueva-2026",
      password_confirmation: "mi-clave-nueva-2026" }.merge(cambios)
  end
end
