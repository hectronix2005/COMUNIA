require "test_helper"

# Cada comunidad raíz tiene una categoría (Club, Barrio, Masonería…) que fija cómo se llaman las cosas y qué
# módulos se ven. Sus grupos la heredan. Solo el superadmin, en el panel de plataforma, la configura.
class CategoriasTest < ActionDispatch::IntegrationTest
  setup do
    @barrio = Categoria.create!(nombre: "Barrio #{SecureRandom.hex(3)}", termino_miembro: "Vecino", termino_logia: "Conjunto",
                                termino_ayuda: "Fondo común", termino_documentos: "Actas",
                                modulos: %w[tesoreria documentos ayuda negocios])
    @cedritos = logia("Cedritos", categoria: @barrio)
    @alborada = logia("Alborada 140", tenant: @cedritos)
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
  end

  test "las palabras salen del grupo, si no de la comunidad, si no de la categoría" do
    assert_equal "Vecino", @alborada.t_miembro
    assert_equal "Conjunto", @alborada.t_logia
    assert_equal "Cobro", @alborada.t_cobro, "sin palabra en ningún nivel, la de por defecto"
    assert_equal "Barrio #{@barrio.nombre.split.last}", @alborada.organizacion.categoria.nombre

    @cedritos.update!(termino_miembro: "Residente")
    assert_equal "Residente", @alborada.reload.t_miembro
    assert_equal "#{@barrio.nombre} · Cedritos · Alborada 140", @alborada.ruta_comunidad
  end

  test "la categoría se asigna a la comunidad, no a uno de sus grupos" do
    @alborada.categoria = @barrio
    assert_not @alborada.valid?
    assert @alborada.errors[:categoria].any?
  end

  test "un módulo que la categoría no usa desaparece del menú y su ruta lleva al panel" do
    yo = persona("Yo", @cedritos)
    sign_in yo
    get "/t/#{@cedritos.slug}/biblioteca/libros"
    assert_redirected_to "/t/#{@cedritos.slug}/dashboard"

    get "/t/#{@cedritos.slug}/dashboard"
    assert_response :ok
    assert_no_match "biblioteca/libros", response.body
    assert_match "Actas", response.body
    assert_match "Fondo común", response.body
    assert_no_match />\s*Hospitalia\s*</i, response.body, "el texto visible usa la palabra de la categoría"
  end

  test "sin grados, todos ven todos los documentos" do
    yo = persona("Aprendiz", @cedritos, grado: "Aprendiz")
    maestro = BibliotecaPlancha.create!(logia: @cedritos, user: yo, titulo: "Acta de maestros", grado: "Maestro")
    sign_in yo
    get "/t/#{@cedritos.slug}/biblioteca/planchas"
    assert_match "Acta de maestros", response.body
    get "/t/#{@cedritos.slug}/biblioteca/planchas/#{maestro.id}"
    assert_response :ok

    @cedritos.update!(categoria: nil)
    get "/t/#{@cedritos.slug}/biblioteca/planchas/#{maestro.id}"
    assert_redirected_to "/t/#{@cedritos.slug}/biblioteca/planchas", "con grados, el aprendiz no abre lo del maestro"
  end

  test "solo el superadmin, en el panel de plataforma, configura las categorías" do
    sign_in persona("Yo", @cedritos)
    get "/categorias"
    assert_redirected_to "/"
    assert_no_difference -> { Categoria.count } do
      post "/categorias", params: { categoria: { nombre: "Intruso" } }
    end

    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    sign_in User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", rol_ref: rol)
    get "/categorias"
    assert_response :ok
    assert_match "Cedritos", response.body

    post "/categorias", params: { categoria: { nombre: "Club #{SecureRandom.hex(2)}", termino_miembro: "Socio",
                                               modulos: ["", "tesoreria", "borrar_todo"] } }
    assert_equal %w[tesoreria], Categoria.order(:id).last.modulos, "solo módulos conocidos"

    delete "/categorias/#{@barrio.id}"
    assert Categoria.exists?(@barrio.id), "con comunidades no se borra"
  end

  test "la comunidad puede tener sus propios módulos; sus grupos los heredan y sin elegir vuelve a la categoría" do
    assert @alborada.modulo?(:tesoreria), "de la categoría"
    @cedritos.update!(modulos_propios: "1", modulos: ["", "reuniones", "inventado"])
    assert_equal %w[reuniones], @cedritos.reload.modulos, "solo módulos conocidos"
    assert_not @alborada.reload.modulo?(:tesoreria), "el grupo hereda la elección de su comunidad"
    assert @alborada.modulo?(:reuniones), "aunque la categoría no lo traiga"

    @cedritos.update!(modulos_propios: "1", modulos: [""])
    assert_equal [], @cedritos.reload.modulos, "elegir ninguno deja solo lo de siempre"
    assert_not @cedritos.modulo?(:documentos)

    @cedritos.update!(modulos_propios: "0", modulos: ["", "reuniones"])
    assert_nil @cedritos.reload.modulos, "sin la casilla, vuelve a la categoría"
    assert @cedritos.modulo?(:tesoreria)

    @alborada.modulos = %w[tesoreria]
    assert_not @alborada.valid?, "los módulos no se eligen en un grupo"
  end

  test "un módulo apagado en la comunidad desaparece del menú y su ruta lleva al panel" do
    @cedritos.update!(modulos_propios: "1", modulos: %w[biblioteca])
    sign_in persona("Yo", @cedritos)
    get "/t/#{@cedritos.slug}/cobros"
    assert_redirected_to "/t/#{@cedritos.slug}/dashboard"
    get "/t/#{@cedritos.slug}/dashboard"
    assert_match "biblioteca/libros", response.body
    assert_no_match "Actas", response.body
  end

  test "sin tesorería ni biblioteca, ningún inicio enseña cobros, y los documentos se llaman como en la comunidad" do
    @cedritos.update!(modulos_propios: "1", modulos: %w[documentos reuniones])
    sign_in persona("Yo", @cedritos)
    get "/t/#{@cedritos.slug}/dashboard"
    assert_response :ok
    assert_select "#mis-cobros", 0
    assert_select "#pay-bar", 0
    assert_select ".modulo-titulo", text: "Actas"
    assert_select ".modulo-titulo", text: "Biblioteca", count: 0

    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    sign_in User.create!(nombre: "Super", apellido: "Panel", email: "superp_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", rol_ref: rol)
    get "/t/#{@cedritos.slug}/dashboard"
    assert_response :ok
    assert_select "#tesoreriaBody", 0
    assert_select ".modulo-titulo", text: "Tesorería", count: 0
    assert_select ".modulo-titulo", text: "Actas"

    @cedritos.update!(modulos_propios: "0")
    get "/t/#{@cedritos.slug}/dashboard"
    assert_select "#tesoreriaBody", 1, "con la categoría, que trae tesorería, vuelve"
  end

  test "solo el superadmin, desde el panel de plataforma, elige los módulos de una comunidad" do
    sign_in persona("Admin", @cedritos)
    patch "/tenants/#{@cedritos.id}", params: { logia: { modulos_propios: "1", modulos: %w[biblioteca] } }
    assert_nil @cedritos.reload.modulos

    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super Admin" }
    sign_in User.create!(nombre: "Super", apellido: "Prueba", email: "super_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", rol_ref: rol)
    get "/tenants/#{@cedritos.id}/edit"
    assert_response :ok
    assert_select "input[name='logia[modulos_propios]'][type=checkbox]:not([checked])"
    patch "/tenants/#{@cedritos.id}", params: { logia: { modulos_propios: "1", modulos: ["", "biblioteca", "reuniones"] } }
    assert_equal %w[biblioteca reuniones], @cedritos.reload.modulos
  end

  private

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, **ficha)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: @rol_miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: :activo, **ficha)
    user
  end
end
