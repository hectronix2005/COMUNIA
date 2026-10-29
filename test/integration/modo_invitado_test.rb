require "test_helper"

# Modo invitado: desde el login se entra sin cuenta a la comunidad de demostración (Demo), se mira todo y no se
# guarda nada. Lo que guardaría lleva a «Entra o pide acceso»; la red y las denuncias no se abren; y la
# comunidad de demostración no se cuela como comunidad por defecto de nadie.
class ModoInvitadoTest < ActionDispatch::IntegrationTest
  setup do
    Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    Demo.preparar!
    @comunidad = Demo.logia
  end

  test "desde el login se entra a la demostración y se ve su muro" do
    get "/login"
    assert_includes response.body, "Ver una demostración"

    post "/demo"
    assert_redirected_to "/dashboard"
    follow_redirect!
    follow_redirect! while response.redirect?
    assert_response :success
    assert_includes response.body, "Demostración."

    get "/t/#{Demo::SLUG}/publicaciones"
    assert_response :success
    assert_includes response.body, "jornada de siembra"
    assert_nil Demo.invitado.reload.last_seen_at
  end

  test "las páginas de la demostración se ven sin guardar nada" do
    entrar
    reunion = Reunion.where(logia: @comunidad).celebrada.first
    paginas = ["/dashboard", "/publicaciones", "/calendario", "/reuniones", "/reuniones/#{reunion.id}", "/encuestas",
               "/encuestas/#{Encuesta.where(logia: @comunidad).first.id}", "/negocios",
               "/negocios/#{NegocioAnuncio.where(logia: @comunidad).first.id}", "/biblioteca/libros", "/chat",
               "/directorio", "/notificaciones", "/perfil", "/demo/participar"]
    paginas.each do |pagina|
      get "/t/#{Demo::SLUG}#{pagina}"
      assert_operator response.status, :<, 500, pagina
      assert_no_match %r{/demo/participar\z}, response.location.to_s, pagina
    end
  end

  test "lo que guarda lleva a entrar o pedir acceso y no se guarda" do
    entrar
    publicacion = Publicacion.where(logia: @comunidad).first

    assert_no_difference -> { Publicacion.count + PublicacionLike.count + PublicacionComentario.count } do
      post "/t/#{Demo::SLUG}/publicaciones", params: { publicacion: { contenido: "Hola" } }
      assert_redirected_to "/t/#{Demo::SLUG}/demo/participar"
      assert_equal 303, response.status

      post "/t/#{Demo::SLUG}/publicaciones/#{publicacion.id}/toggle_like", as: :json
      assert_response :forbidden
    end
    assert_no_changes -> { Demo.invitado.reload.updated_at } do
      patch "/t/#{Demo::SLUG}/perfil", params: { user: { nombre: "Otro" } }
    end
  end

  test "lo que guarda al mirarse tampoco se guarda" do
    entrar
    anuncio = NegocioAnuncio.where(logia: @comunidad).first
    assert_no_changes -> { anuncio.reload.vistas_count } do
      get "/t/#{Demo::SLUG}/negocios/#{anuncio.id}"
    end
    assert_response :success


    # Si una página guardara algo al mirarla (aquí, marcar leído un mensaje directo), no se guarda y lleva a participar.
    autor = User.where(logia: @comunidad, invitado: false).first
    mensaje = ChatMensaje.create!(logia: @comunidad, user: autor, destinatario: Demo.invitado, canal: "dm", contenido: "Hola")
    get "/t/#{Demo::SLUG}/chat", params: { con: autor.id }
    assert_redirected_to "/t/#{Demo::SLUG}/demo/participar"
    assert_nil mensaje.reload.leido_at
  end

  test "la red y las denuncias no se abren al invitado" do
    entrar
    get "/red"
    assert_redirected_to "/dashboard"
    get "/denuncias"
    assert_redirected_to "/dashboard"
  end

  test "salir lleva a pedir acceso o a entrar" do
    entrar
    delete "/demo", params: { destino: "pedir" }
    assert_redirected_to "/pedir-acceso"
    get "/dashboard"
    assert_redirected_to "/login"

    entrar
    delete "/t/#{Demo::SLUG}/demo", params: { destino: "login" }
    assert_redirected_to "/login"
  end

  test "con sesión propia no se entra a la demostración ni se sale por ella" do
    usuario = User.create!(nombre: "Rosa", apellido: "Prueba", email: "rosa_#{SecureRandom.hex(3)}@correo.co", password: "password123",
                           logia: Logia.reales.first || Logia.create!(nombre: "Club Real", codigo: "REAL"), rol: :miembro)
    sign_in usuario
    post "/demo"
    assert_redirected_to "/"
    sign_in usuario
    delete "/demo"
    assert_redirected_to "/"
    assert_not_equal @comunidad, usuario.reload.logia
  end

  test "renovar la demostración conserva a las personas y repone el contenido" do
    personas = User.where(logia: @comunidad).ids.sort
    Publicacion.where(logia: @comunidad).first.destroy
    Demo.preparar!
    assert_equal personas, User.where(logia: @comunidad).ids.sort
    assert_equal 5, Publicacion.where(logia: @comunidad).count
    assert_equal 1, Logia.where(demo: true).count
  end

  test "la demostración no es la comunidad por defecto" do
    assert_not_includes Logia.reales, @comunidad
  end

  private

  def entrar
    post "/demo"
    assert_redirected_to "/dashboard"
  end
end
