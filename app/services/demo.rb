# Comunidad de demostración del modo invitado (DemoController): quien aún no tiene cuenta entra con la cuenta
# compartida `invitado` y mira el muro, el calendario, las reuniones, las encuestas, los negocios y la biblioteca
# sin poder guardar nada. Todo es FICTICIO: personas, cédulas y correos (@ejemplo.invalid no existe).
#
# `Demo.preparar!` crea la comunidad si falta y renueva su contenido con fechas cercanas a hoy; lo repite cada
# noche DemoJob. Las personas y la cuenta del invitado se conservan (su sesión sigue valiendo); lo demás se borra
# y se vuelve a crear. Nada de lo que se crea aquí avisa a nadie: el chat se inserta sin callbacks y los
# recordatorios quedan dados por enviados.
module Demo
  DOMINIO = "ejemplo.invalid".freeze
  SLUG = "demostracion".freeze

  PERSONAS = [
    ["Lucía", "Herrera", "Presidenta", "Arquitecta"],
    ["Andrés", "Gómez", "Secretario", "Profesor de música"],
    ["Camila", "Ruiz", "Tesorera", "Contadora"],
    ["Mateo", "Salazar", nil, "Electricista"],
    ["Valentina", "Ortiz", nil, "Bibliotecóloga"],
    ["Julián", "Pardo", nil, "Ingeniero de sistemas"],
    ["Daniela", "Mejía", nil, "Panadera"],
    ["Santiago", "Rojas", nil, "Asesor financiero"],
    ["Paula", "Cárdenas", nil, "Administradora de empresas"],
    ["Felipe", "Arango", nil, "Ciclista y entrenador"]
  ].freeze

  module_function

  def logia = Logia.find_by(demo: true)
  def invitado = User.find_by(invitado: true)
  def disponible? = invitado&.logia&.demo? || false

  def preparar!
    ActiveRecord::Base.transaction do
      comunidad = preparar_comunidad
      gente = PERSONAS.each_with_index.map { |(nombre, apellido, _, profesion), i| persona(comunidad, nombre, apellido, profesion, i + 1) }
      cuenta_invitado(comunidad)
      vaciar(comunidad, gente)
      poblar(comunidad, gente)
    end
  end

  def preparar_comunidad
    comunidad = Logia.find_or_initialize_by(demo: true)
    comunidad.assign_attributes(nombre: "Club Los Robles (demostración)", codigo: "DEMO", slug: SLUG,
                                lema: "Comunidad de demostración: personas y datos ficticios", icono: "🌳",
                                color_primario: "#2E6B4F", termino_miembro: "Socio", termino_logia: "Club")
    comunidad.save!
    comunidad
  end

  def persona(comunidad, nombre, apellido, profesion, numero)
    slug = I18n.transliterate("#{nombre}.#{apellido}").downcase
    user = User.find_or_initialize_by(email: "demo.#{slug}@#{DOMINIO}")
    user.password = SecureRandom.base58(32) if user.new_record?
    user.assign_attributes(nombre: nombre, apellido: apellido, username: "demo#{slug.delete('.')}", logia: comunidad,
                           rol_ref: Rol.find_by(codigo: "miembro"), last_seen_at: (numero * 7).hours.ago)
    user.save!
    miembro = user.miembro || user.build_miembro
    miembro.update!(logia: comunidad, numero_miembro: format("DEMO-%03d", numero), cedula: format("DEMO%07d", numero),
                    estado: :activo, profesion: profesion, fecha_ingreso: (numero * 5).months.ago.to_date)
    user
  end

  def cuenta_invitado(comunidad)
    user = User.find_or_initialize_by(invitado: true)
    user.password = SecureRandom.base58(32) if user.new_record?
    user.assign_attributes(email: "invitado@#{DOMINIO}", nombre: "Invitado", apellido: "Demostración", username: "demoinvitado",
                           logia: comunidad, rol_ref: Rol.find_by(codigo: "miembro"), last_seen_at: nil)
    user.save!
    miembro = user.miembro || user.build_miembro
    miembro.update!(logia: comunidad, numero_miembro: "DEMO-000", cedula: "DEMO0000000", estado: :activo)
  end

  def vaciar(comunidad, gente)
    ids = [comunidad.id]
    ChatMensaje.where(logia_id: ids).delete_all
    Reunion.where(logia_id: ids).destroy_all
    CalendarioEvento.where(logia_id: ids).destroy_all
    Publicacion.where(logia_id: ids).destroy_all
    Encuesta.where(logia_id: ids).destroy_all
    NegocioAnuncio.where(logia_id: ids).destroy_all
    BibliotecaLibro.where(logia_id: ids).destroy_all
    MiembroCargo.where(miembro_id: Miembro.where(logia_id: ids).select(:id)).delete_all
    Notificacion.where(user_id: gente.map(&:id) << invitado.id).delete_all
  end

  def poblar(comunidad, gente)
    lucia, andres, camila, mateo, valentina, julian, daniela, santiago, paula, felipe = gente
    cargos(comunidad, gente)
    muro(comunidad, gente)
    calendario(comunidad, gente, mateo, paula)
    reuniones(comunidad, gente, lucia, andres, camila)
    encuestas(comunidad, gente, julian)
    negocios(comunidad, mateo, daniela, santiago, paula, felipe)
    biblioteca(comunidad, valentina)
    chat(comunidad, [lucia, andres, camila, mateo, valentina, julian, daniela, santiago, paula, felipe])
  end

  def cargos(comunidad, gente)
    PERSONAS.each_with_index do |(_, _, cargo, _), i|
      next unless cargo
      MiembroCargo.create!(miembro: gente[i].miembro, cargo: Cargo.find_or_create_by!(logia: comunidad, nombre: cargo),
                           desde: 8.months.ago.to_date)
    end
  end

  def muro(comunidad, gente)
    lucia, andres, camila, mateo, valentina, julian = gente
    publicar(comunidad, lucia, 3.days.ago, fijada: true, texto: <<~TXT, comentarios: [[andres, "¡Gracias, Lucía! Ahí estaremos."], [camila, "Confirmado desde el calendario 👍"]])
      ¡Bienvenidos a la comunidad! Aquí compartimos las noticias del club, las fotos de los encuentros y lo que
      cada uno necesite. Recuerden confirmar desde el calendario si vienen al encuentro de esta semana.
    TXT
    publicar(comunidad, andres, 20.hours.ago, texto: <<~TXT, comentarios: [[valentina, "Qué bonito quedó el parque 🌱"], [julian, "La próxima llevo a mis hijos."], [lucia, "Gracias a todos los que vinieron."]])
      Gracias a los que vinieron a la jornada de siembra del sábado: plantamos 40 árboles en el parque del barrio.
      La próxima jornada la cuadramos en el encuentro.
    TXT
    publicar(comunidad, camila, 9.hours.ago, texto: <<~TXT, comentarios: [[mateo, "Te puedo ayudar yo, tengo el anuncio en Negocios."], [camila, "¡Perfecto, Mateo! Te escribo por el chat."]])
      ¿Alguien recomienda un electricista de confianza? Se me dañó el tablero de la casa.
    TXT
    publicar(comunidad, julian, 5.hours.ago, texto: <<~TXT, comentarios: [[andres, "Ya voté."]])
      Recordatorio: la encuesta del paseo de fin de año cierra esta semana. ¡Falta que voten varios!
    TXT
    publicar(comunidad, valentina, 2.hours.ago, texto: <<~TXT, comentarios: [])
      Llegaron dos libros nuevos a la biblioteca del club. Los dejé reseñados en la sección Biblioteca.
    TXT
  end

  def publicar(comunidad, autor, cuando, texto:, comentarios:, fijada: false)
    publicacion = Publicacion.create!(logia: comunidad, user: autor, contenido: texto.squish, fijada: fijada,
                                      created_at: cuando, updated_at: cuando)
    comentarios.each_with_index do |(quien, comentario), i|
      PublicacionComentario.create!(publicacion: publicacion, user: quien, contenido: comentario, created_at: cuando + (i + 1) * 25.minutes)
    end
    Miembro.where(logia: comunidad).includes(:user).where.not(user: invitado).sample(rand(3..8), random: Random.new(publicacion.id))
           .each { PublicacionLike.create!(publicacion: publicacion, user: _1.user) }
  end

  def calendario(comunidad, gente, mateo, paula)
    hoy = Date.current
    torneo = evento(comunidad, mateo, "Torneo de tenis de mesa", hoy + 5, 9, 13, "Cancha cubierta del club",
                    "Inscripciones abiertas hasta el día anterior. Hay raquetas para prestar.")
    evento(comunidad, paula, "Cine al parque", hoy + 9, 19, 21, "Parque del barrio", "Llevar cobija y algo para compartir.")
    evento(comunidad, gente.first, "Jornada de siembra", hoy - 4, 8, 12, "Parque del barrio", "Gracias a todos los que vinieron.")
    gente.first(6).each_with_index do |persona, i|
      EventoConfirmacion.create!(calendario_evento: torneo, user: persona, estado: i < 5 ? :confirmado : :rechazado)
    end
  end

  def evento(comunidad, autor, titulo, dia, desde, hasta, lugar, descripcion)
    inicio = Time.zone.local(dia.year, dia.month, dia.day, desde)
    CalendarioEvento.create!(logia: comunidad, user: autor, titulo: titulo, descripcion: descripcion, ubicacion: lugar,
                             inicio: inicio, fin: inicio.change(hour: hasta), recordatorio_enviado_at: Time.current)
  end

  def reuniones(comunidad, gente, lucia, andres, camila)
    proxima = (Date.current + 2).in_time_zone.change(hour: 19)
    convocada = Reunion.create!(logia: comunidad, user: lucia, titulo: "Encuentro mensual", lugar: "Salón comunal",
                                inicio: proxima, fin: proxima + 2.hours, recordatorio_enviado_at: Time.current,
                                orden_del_dia: <<~TXT)
                                  1. Bienvenida y lectura del acta anterior
                                  2. Informe de tesorería
                                  3. Paseo de fin de año: resultado de la encuesta
                                  4. Próxima jornada de siembra
                                  5. Proposiciones y varios
                                TXT
    convocada.calendario_evento&.update_column(:recordatorio_enviado_at, Time.current)
    gente.first(7).each_with_index do |persona, i|
      EventoConfirmacion.create!(calendario_evento: convocada.calendario_evento, user: persona, estado: i < 6 ? :confirmado : :rechazado) if convocada.calendario_evento
    end

    pasada = 26.days.ago.change(hour: 19)
    celebrada = Reunion.create!(logia: comunidad, user: lucia, titulo: "Encuentro mensual", lugar: "Salón comunal",
                                inicio: pasada, fin: pasada + 2.hours, estado: :celebrada, recordatorio_enviado_at: pasada,
                                orden_del_dia: "1. Bienvenida\n2. Jornada de siembra\n3. Torneo de tenis de mesa\n4. Varios",
                                acta: <<~TXT, acta_publicada_at: pasada + 1.day)
                                  Asistieron siete socios. Se aprobó la jornada de siembra en el parque del barrio y se abrió la
                                  inscripción al torneo de tenis de mesa. Camila presentó el informe de tesorería: las cuentas
                                  están al día. Se acordó hacer una encuesta para elegir el destino del paseo de fin de año.
                                TXT
    celebrada.calendario_evento&.update_column(:recordatorio_enviado_at, pasada)
    gente.first(7).each { ReunionAsistencia.create!(reunion: celebrada, miembro: _1.miembro) }
    [["Conseguir los árboles para la jornada de siembra", andres, -10, true],
     ["Abrir la encuesta del paseo de fin de año", camila, -5, true],
     ["Cotizar el alquiler del bus para el paseo", lucia, 6, false]].each do |texto, quien, dias, cumplido|
      ReunionAcuerdo.create!(reunion: celebrada, responsable: quien.miembro, texto: texto, vence_el: Date.current + dias,
                             cumplido_at: (cumplido ? (Date.current + dias - 1).in_time_zone : nil), recordatorio_enviado_at: Time.current)
    end
  end

  def encuestas(comunidad, gente, julian)
    votar(comunidad, julian, "¿A dónde vamos en el paseo de fin de año?", ["Finca en Guatapé", "Playa en Santa Marta", "Día de campo en Santa Elena"],
          [4, 2, 1], cierre: 4.days.from_now, descripcion: "El resultado se presenta en el próximo encuentro.")
    votar(comunidad, gente.first, "¿Qué horario prefieren para los encuentros?", ["Jueves 7 p. m.", "Sábado 10 a. m."], [6, 3],
          cierre: 20.days.ago, estado: :cerrada)
  end

  def votar(comunidad, autor, titulo, opciones, votos, cierre:, descripcion: nil, estado: :activa)
    encuesta = Encuesta.new(logia: comunidad, user: autor, titulo: titulo, descripcion: descripcion, cierre_en: cierre, estado: estado)
    opciones.each_with_index { |texto, i| encuesta.encuesta_opciones.build(texto: texto, posicion: i) }
    encuesta.save!
    votantes = Miembro.where(logia: comunidad).where.not(user: invitado).includes(:user).map(&:user).each
    encuesta.encuesta_opciones.zip(votos).each { |opcion, n| n.times { EncuestaVoto.create!(encuesta_opcion: opcion, user: votantes.next) } }
  end

  def negocios(comunidad, mateo, daniela, santiago, paula, felipe)
    [[mateo, "Instalaciones eléctricas residenciales", "servicio", "Construcción", nil, "Revisión de tableros, tomas e iluminación. Visita sin costo para socios."],
     [daniela, "Pan de masa madre por encargo", "producto", "Alimentación", 18_000, "Hornada los viernes. Pedidos hasta el miércoles."],
     [santiago, "Asesoría contable para pequeños negocios", "servicio", "Finanzas", nil, "Declaración de renta, facturación electrónica y flujo de caja."],
     [paula, "Auxiliar administrativo de medio tiempo", "empleo", "Medio tiempo", nil, "Para una empresa de un socio. Mañanas, de lunes a viernes."],
     [felipe, "Bicicleta de ruta talla M", "producto", "Deportes", 1_200_000, "Poco uso, con mantenimiento al día."]].each_with_index do |(autor, titulo, tipo, categoria, precio, descripcion), i|
      NegocioAnuncio.create!(logia: comunidad, user: autor, titulo: titulo, tipo: tipo, categoria: categoria, precio: precio,
                             descripcion: descripcion, contacto: "Por el chat de la comunidad", ubicacion: "Medellín",
                             estado: i == 4 ? "reservado" : "disponible", created_at: (i + 1).days.ago)
    end
  end

  def biblioteca(comunidad, valentina)
    [["Cien años de soledad", "Gabriel García Márquez", "Literatura", 1967],
     ["Meditaciones", "Marco Aurelio", "Filosofía", 180],
     ["Breve historia del tiempo", "Stephen Hawking", "Ciencia", 1988],
     ["Sapiens", "Yuval Noah Harari", "Historia", 2011]].each do |titulo, autor, categoria, anio|
      BibliotecaLibro.create!(logia: comunidad, user: valentina, titulo: titulo, autor: autor, categoria: categoria, anio: anio,
                              descripcion: "Ejemplar del club: se presta por dos semanas.")
    end
  end

  def chat(comunidad, gente)
    lucia, andres, camila, mateo, valentina, julian, daniela = gente
    ahora = Time.current
    filas = [[lucia, 26, "Buenas noches a todos. ¿Quién se encarga del refrigerio del encuentro?"],
             [daniela, 25, "Yo llevo pan 🙌"],
             [andres, 24, "Yo llevo el café."],
             [camila, 8, "Ya está el informe de tesorería para el encuentro."],
             [mateo, 7, "Camila, mañana paso a revisar el tablero."],
             [camila, 7, "¡Gracias, Mateo!"],
             [valentina, 3, "Les dejo los libros nuevos en la biblioteca 📚"],
             [julian, 1, "No olviden votar la encuesta del paseo."]].map do |autor, horas, texto|
      { logia_id: comunidad.id, user_id: autor.id, contenido: texto, canal: "logia", created_at: ahora - horas.hours, updated_at: ahora - horas.hours }
    end
    ChatMensaje.insert_all!(filas)
  end
end
