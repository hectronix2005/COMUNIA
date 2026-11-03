require "test_helper"

# El resumen de los lunes (ResumenSemanal, ResumenSemanalJob, /semana): a cada miembro lo de su semana, con el
# alcance de cada pantalla; al admin, el texto para el grupo de WhatsApp sin nada personal ni de los grupos.
class ResumenSemanalTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  setup do
    preparar_denuncias
    @admin = vecino("Adela", rol: "admin_logia")
    rol = @admin.rol_ref
    rol.permisos << Permiso.find_or_create_by!(recurso: "miembros", accion: "index") unless rol.tiene_permiso?("miembros", "index")
    @comunidad = @admin.logia
    @grupo_a = grupo("Torre A")
    @grupo_b = grupo("Torre B")
    @vera = en_grupo(vecino("Vera"), @grupo_a)
    @beto = en_grupo(vecino("Beto"), @grupo_b)

    @asamblea = reunion(@comunidad, "Asamblea general", 2.days.from_now, lugar: "Salón comunal")
    reunion(@grupo_b, "Reunión de la torre B", 3.days.from_now)
    reunion(@comunidad, "La del mes que viene", 20.days.from_now)
    CalendarioEvento.create!(logia: @grupo_a, user: @admin, titulo: "Fumigación torre A", inicio: 1.day.from_now, fin: 1.day.from_now + 2.hours)
    @encuesta = Encuesta.create!(logia: @comunidad, user: @admin, titulo: "¿Pintamos la fachada?", estado: :activa,
                                 encuesta_opciones: [EncuestaOpcion.new(texto: "Sí", posicion: 1), EncuestaOpcion.new(texto: "No", posicion: 2)])
    Publicacion.create!(logia: @grupo_b, user: @beto, contenido: "Se encontró un gato gris en el parqueadero", created_at: 1.day.ago)
    Publicacion.create!(logia: @comunidad, user: @beto, contenido: "Una vieja", created_at: 10.days.ago)
  end

  teardown { limpiar_denuncias }

  def grupo(nombre) = Logia.create!(nombre:, slug: "grupo-#{SecureRandom.hex(4)}", codigo: "L#{SecureRandom.hex(3).upcase}", tenant_id: @comunidad.id)

  def en_grupo(user, logia)
    Miembro.find_by!(user:).update!(logia:)
    user.update!(logia:)
    user
  end

  def reunion(logia, titulo, inicio, lugar: nil)
    Reunion.create!(logia:, user: @admin, titulo:, inicio:, fin: inicio + 2.hours, lugar:, estado: :convocada)
  end

  test "cada uno ve lo de la raíz y lo de su grupo; no lo de los grupos hermanos, ni lo que ya votó ni lo suyo" do
    @encuesta.encuesta_opciones.first.encuesta_votos.create!(user: @vera)

    vera = ResumenSemanal.new(@comunidad, user: @vera)
    assert_equal ["Asamblea general"], vera.reuniones.map(&:titulo), "ni la de la torre B ni la de dentro de 20 días"
    assert_equal ["Fumigación torre A"], vera.eventos.map(&:titulo)
    assert_empty vera.encuestas, "ya votó"
    assert_equal 1, vera.publicaciones, "la de hace 10 días no cuenta"
    assert_equal "Esta semana en #{@comunidad.nombre_display}", vera.titulo
    assert_match(/\A1 reunión, 1 evento y 1 publicación nueva en el muro\z/i, vera.cuerpo)

    beto = ResumenSemanal.new(@comunidad, user: @beto)
    assert_equal ["Asamblea general", "Reunión de la torre B"], beto.reuniones.map(&:titulo)
    assert_empty beto.eventos
    assert_equal [@encuesta], beto.encuestas
    assert_equal 0, beto.publicaciones, "la suya no se la cuenta"
  end

  test "el texto de WhatsApp lleva solo lo de toda la comunidad, sin el muro ni cumpleaños" do
    texto = ResumenSemanal.new(@comunidad).texto_whatsapp("https://comunia.test/t/x/semana")
    assert_match "*Esta semana en #{@comunidad.nombre_display}*", texto
    assert_match "Asamblea general", texto
    assert_match "Salón comunal", texto
    assert_match "Encuesta abierta: ¿Pintamos la fachada?", texto
    assert_match "1 publicación nueva en el muro", texto
    assert_no_match(/torre B|Fumigación|gato/i, texto)
    assert texto.end_with?("https://comunia.test/t/x/semana")
  end

  test "el lunes avisa a cada miembro activo con algo que ver, y a nadie de una comunidad sin nada" do
    callado = vecino("Ciro")
    assert_difference -> { Notificacion.where(tipo: "resumen_semanal", user: [@admin, @vera, @beto]).count }, 3 do
      ResumenSemanalJob.perform_now
    end
    aviso = Notificacion.find_by!(tipo: "resumen_semanal", user: @vera)
    assert_equal [@comunidad, "/semana"], [aviso.logia, aviso.url]
    assert_not Notificacion.exists?(tipo: "resumen_semanal", user: callado)
  end

  test "la página /semana: el miembro ve lo suyo; solo el admin de la comunidad tiene el texto para WhatsApp" do
    sign_in @vera
    get "/t/#{@comunidad.slug}/semana"
    assert_response :success
    assert_match "Asamblea general", response.body
    assert_match "Fumigación torre A", response.body
    assert_match "Se encontró un gato gris", response.body
    assert_no_match "Para el grupo de WhatsApp", response.body
    sign_out :user

    sign_in @admin
    get "/t/#{@comunidad.slug}/dashboard"
    assert_match "Resumen de la semana", response.body
    get "/t/#{@comunidad.slug}/semana"
    assert_match "Para el grupo de WhatsApp", response.body
    assert_match %r{Confirma, vota y comenta en COMUNIA: http://[^<]+/t/#{@comunidad.slug}/semana}, response.body
  end
end
