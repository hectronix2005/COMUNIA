require "test_helper"

# Dos personas que comparten dos comunidades tienen un privado en cada una: lo escrito en una no sale en la otra.
# Las conversaciones de negocios son del anuncio, y el anuncio es de una comunidad. Y el nombre o el correo de una
# cuenta que es también de otra comunidad no los cambia el admin de esta.
class ChatYNegociosPorComunidadTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @luz = Logia.create!(nombre: "Logia Luz", slug: "luz-#{SecureRandom.hex(2)}", codigo: "L#{SecureRandom.hex(3).upcase}")
    @andes = Logia.create!(nombre: "Egresados Andes", slug: "andes-#{SecureRandom.hex(2)}", codigo: "A#{SecureRandom.hex(3).upcase}")
    @ana = usuario("Ana")
    @beto = usuario("Beto")
    [@ana, @beto].each { |u| ficha(u, @luz); ficha(u, @andes); u.unir_a_comunidad!(@andes) }
  end

  test "el privado escrito en una comunidad no sale en la otra" do
    sign_in @ana
    post "/t/#{@luz.slug}/chat", params: { con: @beto.id, contenido: "Hablamos de la tenida" }
    assert_response :ok
    post "/t/#{@andes.slug}/chat", params: { con: @beto.id, contenido: "Nos vemos en el asado" }
    assert_response :ok

    sign_out :user
    sign_in @beto
    get "/t/#{@luz.slug}/chat", params: { con: @ana.id }
    assert_includes response.body, "Hablamos de la tenida"
    assert_not_includes response.body, "Nos vemos en el asado"
    assert_includes response.body, ChatMensaje.stream_dm(@luz, @ana.id, @beto.id)

    get "/t/#{@andes.slug}/chat", params: { con: @ana.id }
    assert_includes response.body, "Nos vemos en el asado"
    assert_not_includes response.body, "Hablamos de la tenida"

    get "/t/#{@andes.slug}/chat/buscar", params: { canal: "dm", con: @ana.id, q: "tenida" }
    assert_not_includes response.body, "Hablamos de la tenida"
  end

  test "leer un privado en una comunidad no marca los de la otra" do
    sign_in @ana
    post "/t/#{@luz.slug}/chat", params: { con: @beto.id, contenido: "En Luz" }
    post "/t/#{@andes.slug}/chat", params: { con: @beto.id, contenido: "En Andes" }
    sign_out :user

    sign_in @beto
    get "/t/#{@luz.slug}/chat", params: { con: @ana.id }
    assert ChatMensaje.find_by(contenido: "En Luz").leido?
    assert_not ChatMensaje.find_by(contenido: "En Andes").leido?
  end

  test "las conversaciones de negocios solo se ven en la comunidad del anuncio" do
    anuncio = NegocioAnuncio.create!(logia: @luz, user: @beto, titulo: "Vendo bicicleta", tipo: "producto")
    conv = NegocioConversacion.create!(negocio_anuncio: anuncio, comprador: @ana, vendedor: @beto)
    conv.mensajes.create!(user: @ana, cuerpo: "¿Sigue disponible?")

    sign_in @ana
    get "/t/#{@luz.slug}/mis-conversaciones"
    assert_includes response.body, "Vendo bicicleta"
    get "/t/#{@andes.slug}/mis-conversaciones"
    assert_not_includes response.body, "Vendo bicicleta"

    get "/t/#{@andes.slug}/mis-conversaciones/#{conv.id}"
    assert_response :not_found
    post "/t/#{@andes.slug}/mis-conversaciones/#{conv.id}/mensajes", params: { negocio_mensaje: { cuerpo: "Hola" } }
    assert_response :not_found
    assert_equal 1, conv.mensajes.count
  end

  test "el admin no edita una cuenta que es también de otra comunidad" do
    rol_admin = Rol.create!(nombre: "Admin #{SecureRandom.hex(2)}", codigo: "admin_#{SecureRandom.hex(2)}")
    rol_admin.permisos << Permiso.find_or_create_by!(recurso: "roles", accion: "update")
    admin = User.create!(nombre: "Ada", apellido: "Prueba", email: "ada_#{SecureRandom.hex(3)}@correo.co",
                         password: "password123", logia: @luz, rol_ref: rol_admin)
    solo_luz = usuario("Carla")
    assert UserPolicy.new(admin, solo_luz).update?
    assert_not UserPolicy.new(admin, @ana).update?
  end

  private

  def usuario(nombre)
    User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                 password: "password123", logia: @luz, rol_ref: @rol_miembro)
  end

  def ficha(user, logia)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
  end
end
