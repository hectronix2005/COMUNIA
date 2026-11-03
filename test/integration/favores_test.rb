require "test_helper"

# «Pido / ofrezco» (Favor, FavoresController, AvisarFavorJob) y la pregunta de la semana del muro: solo en las
# comunidades con el módulo; un «pido» avisa a los vecinos, un «ofrezco» no; «Puedo ayudar» abre el chat; el autor
# resuelve y da las gracias; nada cruza de comunidad. Y los dos entran en el resumen de los lunes.
class FavoresTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba
  include ActiveJob::TestHelper

  setup do
    preparar_denuncias
    @ana = vecino("Ana")
    @comunidad = @ana.logia
    @comunidad.update!(modulos: %w[pido_ofrezco])
    @beto = vecino("Beto")
    @beto.update!(logia: @comunidad)
    Miembro.find_by!(user: @beto).update!(logia: @comunidad)
    @admin = vecino("Adela", rol: "admin_logia")
    @admin.update!(logia: @comunidad)
    Miembro.find_by!(user: @admin).update!(logia: @comunidad)
    @ajeno = vecino("Fede") # de otra comunidad
    @base = "/t/#{@comunidad.slug}"
  end

  teardown { limpiar_denuncias }

  def pedir(user, titulo, tipo: "pido")
    post "#{@base}/favores", params: { favor: { tipo:, titulo:, detalle: "Gracias" } }
    Favor.where(user:).order(:id).last
  end

  test "un «pido» avisa a los vecinos de la comunidad; un «ofrezco» no; como mucho 3 abiertos" do
    sign_in @ana
    favor = nil
    perform_enqueued_jobs only: AvisarFavorJob do
      favor = pedir(@ana, "¿Alguien me presta un taladro?")
    end
    assert_equal [@comunidad, "pido", "abierto"], [favor.logia, favor.tipo, favor.estado]
    avisados = Notificacion.where(tipo: "favor_pido", url: "/favores/#{favor.id}").pluck(:user_id)
    assert_includes avisados, @beto.id
    assert_includes avisados, @admin.id
    assert_not_includes avisados, @ana.id, "a quien pide no se le avisa"
    assert_not_includes avisados, @ajeno.id, "no cruza de comunidad"

    assert_no_difference -> { Notificacion.where(tipo: "favor_pido").count } do
      perform_enqueued_jobs(only: AvisarFavorJob) { pedir(@ana, "Paseo perros los sábados", tipo: "ofrezco") }
    end

    2.times { pedir(@ana, "Otro pedido #{_1}") }
    assert_no_difference -> { Favor.count } do
      post "#{@base}/favores", params: { favor: { tipo: "pido", titulo: "El cuarto" } }
    end
    assert_response :unprocessable_entity
    assert_match "Ya tienes 3 pedidos abiertos", response.body

    assert_no_difference -> { Favor.count } do
      post "#{@base}/favores", params: { favor: { tipo: "otra cosa", titulo: "x" } }
    end
  end

  test "«Puedo ayudar» deja el mensaje en el chat; el autor resuelve y da las gracias" do
    favor = Favor.create!(logia: @comunidad, user: @ana, tipo: "pido", titulo: "Necesito una escalera")

    sign_in @beto
    get "#{@base}/favores"
    assert_match "Necesito una escalera", response.body
    assert_difference -> { ChatMensaje.dm_entre(@beto.id, @ana.id).count }, 1 do
      2.times { post "#{@base}/favores/#{favor.id}/ayudar" }
    end
    assert_redirected_to %r{/chat\?con=#{@ana.id}}
    assert_match "puedo ayudarte con «Necesito una escalera»", ChatMensaje.dm_entre(@beto.id, @ana.id).last.contenido
    patch "#{@base}/favores/#{favor.id}/resolver"
    assert_response :forbidden, "solo el autor lo resuelve"
    sign_out :user

    sign_in @ana
    get "#{@base}/favores/#{favor.id}"
    assert_match "Dale las gracias", response.body
    patch "#{@base}/favores/#{favor.id}/resolver", params: { ayudante_id: @ajeno.id }
    assert_nil favor.reload.ayudante, "solo puede agradecer a quien respondió"
    favor.update!(estado: "abierto")
    patch "#{@base}/favores/#{favor.id}/resolver", params: { ayudante_id: @beto.id }
    assert_equal ["resuelto", @beto], [favor.reload.estado, favor.ayudante]
    assert Notificacion.exists?(user: @beto, tipo: "favor_gracias")
    get "#{@base}/favores"
    assert_match "Resuelto con #{@beto.nombre_corto}", response.body
  end

  test "lo de otra comunidad es un 404 y sin el módulo no se entra" do
    otro = Favor.create!(logia: @ajeno.logia, user: @ajeno, tipo: "pido", titulo: "De otra parte")
    sign_in @ana
    get "#{@base}/dashboard"
    assert_match "Pido / ofrezco", response.body
    get "#{@base}/favores"
    assert_response :success
    assert_no_match "De otra parte", response.body
    get "#{@base}/favores/#{otro.id}"
    assert_response :not_found
    sign_out :user

    @ajeno.logia.update!(modulos: [])
    sign_in @ajeno
    get "/t/#{@ajeno.logia.slug}/favores"
    assert_redirected_to %r{/dashboard}
  end

  test "quien modera quita lo de otro; un vecino no" do
    favor = Favor.create!(logia: @comunidad, user: @ana, tipo: "ofrezco", titulo: "Vendo empanadas")
    sign_in @beto
    patch "#{@base}/favores/#{favor.id}/cerrar"
    assert_response :forbidden
    sign_out :user

    sign_in @admin
    patch "#{@base}/favores/#{favor.id}/cerrar"
    assert_equal "cerrado", favor.reload.estado
  end

  test "la pregunta de la semana: solo el admin la lanza, queda fijada y sale en el resumen con los favores" do
    sign_in @beto
    post "#{@base}/publicaciones", params: { publicacion: { contenido: "¿Me cuelo?", pregunta: "1" } }
    assert_not Publicacion.find_by!(contenido: "¿Me cuelo?").pregunta?
    sign_out :user

    sign_in @admin
    get "#{@base}/publicaciones"
    assert_match "pregunta de la semana", response.body
    post "#{@base}/publicaciones", params: { publicacion: { contenido: "¿Qué arreglamos primero del parque?", pregunta: "1" } }
    pregunta = Publicacion.find_by!(contenido: "¿Qué arreglamos primero del parque?")
    assert pregunta.pregunta? && pregunta.fijada?
    get "#{@base}/publicaciones"
    assert_match "Pregunta de la semana", response.body

    Favor.create!(logia: @comunidad, user: @ana, tipo: "pido", titulo: "Necesito una escalera")
    Favor.create!(logia: @comunidad, user: @ana, tipo: "ofrezco", titulo: "Clases de guitarra")
    Favor.create!(logia: @comunidad, user: @ana, tipo: "pido", titulo: "Viejo", created_at: 20.days.ago)

    resumen = ResumenSemanal.new(@comunidad, user: @beto)
    assert_equal ["Necesito una escalera", "Clases de guitarra"], resumen.favores.map(&:titulo)
    assert_equal pregunta, resumen.pregunta
    assert_match "1 vecino pide una mano, 1 oferta entre vecinos", resumen.cuerpo
    assert_empty ResumenSemanal.new(@comunidad, user: @ana).favores, "lo propio no se lo cuenta"

    texto = ResumenSemanal.new(@comunidad).texto_whatsapp("https://x")
    assert_match "❓ Pregunta de la semana: «¿Qué arreglamos primero del parque?»", texto
    assert_match "🙋 1 pedido de ayuda y 1 oferta entre vecinos", texto
    assert_no_match "escalera", texto, "el contenido de los favores no sale de COMUNIA"

    get "#{@base}/semana"
    assert_match "Necesito una escalera", response.body
    assert_match "¿Qué arreglamos primero del parque?", response.body
  end
end
