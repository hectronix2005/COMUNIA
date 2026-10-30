require "test_helper"

# Lo de una comunidad solo lo ve quien es de ella. Los archivos (soportes, planchas) no se abren sin sesión ni
# desde otra comunidad aunque se tenga el enlace; el logo sí, porque sale en el ingreso. Y un admin no puede
# apoderarse, con el enlace de invitación o una solicitud de acceso, de una cuenta que es también de otra comunidad.
class DatosPorComunidadTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @luz = Logia.create!(nombre: "Logia Luz", slug: "luz-#{SecureRandom.hex(2)}", codigo: "L#{SecureRandom.hex(3).upcase}")
    @andes = Logia.create!(nombre: "Egresados Andes", slug: "andes-#{SecureRandom.hex(2)}", codigo: "A#{SecureRandom.hex(3).upcase}")

    @de_luz = usuario("Lucia", @luz)
    @de_andes = usuario("Andres", @andes)
    @plancha = BibliotecaPlancha.create!(logia: @luz, user: @de_luz, titulo: "Plancha", grado: "Aprendiz",
                                         documento: { io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: "plancha.pdf",
                                                      content_type: "application/pdf" })
  end

  test "un archivo de la comunidad solo se abre con sesión y siendo de ella" do
    enlace = rails_blob_path(@plancha.documento, only_path: true)

    get enlace
    assert_response :not_found

    sign_in @de_andes
    get enlace
    assert_response :not_found
    sign_out :user

    sign_in @de_luz
    get enlace
    assert_response :redirect

    @de_andes.unir_a_comunidad!(@luz)
    sign_out :user
    sign_in @de_andes
    get enlace
    assert_response :redirect
  end

  test "quien deja la comunidad ya no abre sus archivos con el enlace guardado" do
    @de_andes.unir_a_comunidad!(@luz)
    enlace = rails_blob_path(@plancha.documento, only_path: true)
    @de_andes.salir_de_comunidad!(@luz)
    sign_in @de_andes
    get enlace
    assert_response :not_found
  end

  test "el logo de la comunidad es público" do
    @luz.logo.attach(io: file_fixture("imagen_40x30.png").open, filename: "logo.png", content_type: "image/png")
    get rails_blob_path(@luz.logo, only_path: true)
    assert_response :redirect
  end

  test "un enlace inventado no abre nada" do
    sign_in @de_luz
    get "/rails/active_storage/blobs/redirect/no-es-valido/plancha.pdf"
    assert_response :not_found
  end

  test "el admin no genera el enlace de una cuenta que es también de otra comunidad; el superadmin sí" do
    rol_admin = Rol.create!(nombre: "Admin #{SecureRandom.hex(2)}", codigo: "admin_#{SecureRandom.hex(2)}")
    %w[index show update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) }
    admin = User.create!(nombre: "Ada", apellido: "Prueba", email: "ada_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @luz, rol: :admin_logia, rol_ref: rol_admin)
    ficha = Miembro.create!(user: @de_luz, logia: @luz, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo)
    assert MiembroPolicy.new(admin, ficha).invitar?

    @de_luz.unir_a_comunidad!(@andes)
    @de_luz.activar_comunidad!(@luz)
    assert_not MiembroPolicy.new(admin, ficha.reload).invitar?

    super_rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Superadmin" }
    jefe = User.create!(nombre: "Jefe", apellido: "Prueba", email: "jefe_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: @luz, rol: :super_admin, rol_ref: super_rol)
    assert MiembroPolicy.new(jefe, ficha).invitar?
  end

  test "una solicitud de acceso no se enlaza a una ficha cuya cuenta es también de otra comunidad" do
    ficha = Miembro.create!(user: @de_luz, logia: @luz, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo)
    solicitud = SolicitudAcceso.new(logia: @luz, nombre: "Lucia", apellido: "Prueba", email: "otra@correo.co",
                                    prueba: "Soy de la logia desde 2019")
    assert_includes solicitud.fichas_enlazables, ficha

    @de_luz.unir_a_comunidad!(@andes)
    assert_not_includes solicitud.fichas_enlazables, ficha
  end

  test "sin rol ni logia no se abre ninguna logia" do
    sin_nada = User.new(nombre: "Nadie", apellido: "Prueba")
    assert sin_nada.scope_propia_logia?
    assert_equal [], sin_nada.logia_ids_accesibles
  end

  test "el panel del admin no enseña privados y no se asignan cargos de otra comunidad" do
    rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin" }
    %w[index show update].each { rol_admin.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: _1) unless rol_admin.tiene_permiso?("miembros", _1) }
    admin = User.create!(nombre: "Ada", apellido: "Prueba", email: "ada_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @luz, rol: :admin_logia, rol_ref: rol_admin)
    otro = usuario("Beto", @luz)
    ChatMensaje.create!(logia: @luz, user: @de_luz, destinatario: otro, canal: "dm", contenido: "Secreto entre los dos")
    ChatMensaje.create!(logia: @luz, user: @de_luz, canal: "logia", contenido: "Hola a todos")

    sign_in admin
    get "/t/#{@luz.slug}/dashboard"
    assert_response :ok
    assert_includes response.body, "Hola a todos"
    assert_not_includes response.body, "Secreto entre los dos"

    ficha = Miembro.create!(user: @de_luz, logia: @luz, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo)
    ajeno = Cargo.create!(logia: @andes, nombre: "Cargo secreto de Andes")
    post "/t/#{@luz.slug}/miembros/#{ficha.id}/cargos", params: { miembro_cargo: { cargo_id: ajeno.id, desde: Date.current } }
    assert_empty ficha.miembro_cargos.reload
    follow_redirect!
    assert_not_includes response.body, "Cargo secreto de Andes"
  end

  private

  def usuario(nombre, logia)
    User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                 password: "password123", logia: logia, rol_ref: @rol_miembro)
  end
end
