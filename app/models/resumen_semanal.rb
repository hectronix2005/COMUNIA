# Lo de esta semana en una comunidad: reuniones y eventos de los próximos 7 días, encuestas abiertas, el muro de
# los últimos 7 días, la pregunta de la semana, lo que piden y ofrecen los vecinos y, si están encendidos, los
# cumpleaños. Lo manda ResumenSemanalJob los lunes a todos los
# miembros activos, sin que lo pidan, y lo pinta /semana: según la investigación del 3-nov-2026, un resumen que
# llega fuera de la app (43-59 % de apertura) trae más gente que esperar a que entren (~6 % al mes).
#
# Con persona, respeta el alcance de cada pantalla: reuniones y eventos de la raíz y de su grupo (los grupos
# hermanos no se ven, como en AlcanceReuniones); muro y encuestas, de toda la comunidad; sin lo que ya votó ni lo
# que escribió. Sin persona es el texto para el grupo de WhatsApp de la comunidad: solo lo de la raíz, sin
# cumpleaños (son datos de familiares) ni lo que dice el muro o los «pido / ofrezco» (no sale de COMUNIA; solo
# cuántos hay). La pregunta de la semana sí va: la escribe el admin para toda la comunidad.
class ResumenSemanal
  DIAS = 7

  attr_reader :comunidad, :user, :ahora

  def initialize(comunidad, user: nil, ahora: Time.current)
    @comunidad = comunidad.organizacion
    @user = user
    @ahora = ahora
  end

  def vacio? = [reuniones, eventos, encuestas, cumpleanos, favores].all?(&:empty?) && publicaciones.zero? && pregunta.nil?

  def reuniones
    return [] unless comunidad.modulo?(:reuniones)

    @reuniones ||= Reunion.convocada.where(logia_id: ids_cercanos, inicio: ahora..fin).includes(:logia).order(:inicio).to_a
  end

  def eventos
    @eventos ||= CalendarioEvento.de_logias(ids_cercanos).where.missing(:reunion)
                                 .en_rango(ahora, fin).includes(:logia).ordenados.to_a
  end

  def encuestas
    @encuestas ||= begin
      abiertas = Encuesta.activa.where(logia_id: ids_organizacion)
                         .where("encuestas.cierre_en IS NULL OR encuestas.cierre_en > ?", ahora)
      abiertas = abiertas.where.not(id: EncuestaOpcion.joins(:encuesta_votos).where(encuesta_votos: { user_id: user.id }).select(:encuesta_id)) if user
      abiertas.order(:created_at).to_a
    end
  end

  # Publicaciones nuevas en el muro en los últimos 7 días (sin contar las propias).
  def publicaciones = @publicaciones ||= muro.count

  # La más comentada de la semana, para la página de la persona (no va al texto de WhatsApp).
  def publicacion_destacada
    return unless user

    @publicacion_destacada ||= muro.includes(:user).order(comentarios_count: :desc, likes_count: :desc, created_at: :desc).first
  end

  # La pregunta de la semana que lanzó el admin en el muro (la última de los 7 días).
  def pregunta
    return @pregunta if defined?(@pregunta)

    @pregunta = Publicacion.de_logias(ids_organizacion).where(pregunta: true, created_at: (ahora - DIAS.days)..ahora)
                           .order(created_at: :desc).first
  end

  # «Pido / ofrezco» abiertos de los demás, si la comunidad tiene el módulo: los «pido» primero.
  def favores
    return [] unless comunidad.modulo?(:pido_ofrezco)

    @favores ||= begin
      abiertos = Favor.de_logias(ids_organizacion).vigentes.includes(:user)
      abiertos = abiertos.where.not(user:) if user
      abiertos.sort_by { [_1.pido? ? 0 : 1, -_1.created_at.to_i] }
    end
  end

  # [familiar, fecha] de los próximos 7 días, como CumpleanosSemanaJob, al que sustituye los lunes.
  def cumpleanos
    return [] unless user && comunidad.cumpleanos?

    @cumpleanos ||= begin
      hoy = ahora.to_date
      MiembroFamiliar.con_cumpleanos.where(miembro: Miembro.where(logia_id: ids_organizacion).activos)
                     .includes(miembro: :user).map { [_1, _1.proximo_cumpleanos(hoy)] }
                     .select { |_, fecha| fecha < hoy + DIAS }.sort_by { |f, fecha| [fecha, f.nombre_completo] }
    end
  end

  def titulo = "Esta semana en #{comunidad.nombre_display}"

  # Una línea para el aviso del teléfono: «1 reunión, 2 eventos y 3 publicaciones nuevas en el muro».
  def cuerpo
    partes = []
    partes << contar(reuniones.size, comunidad.t_reunion.downcase, comunidad.t_reuniones.downcase)
    partes << contar(eventos.size, "evento", "eventos")
    partes << contar(encuestas.size, "encuesta por votar", "encuestas por votar")
    partes << contar(cumpleanos.size, "cumpleaños", "cumpleaños")
    partes << contar(favores.count(&:pido?), "vecino pide una mano", "vecinos piden una mano")
    partes << contar(favores.count { !_1.pido? }, "oferta entre vecinos", "ofertas entre vecinos")
    partes << contar(publicaciones, "publicación nueva en el muro", "publicaciones nuevas en el muro")
    partes.unshift("Pregunta de la semana: «#{pregunta.contenido.truncate(80)}»") if pregunta
    partes.compact.to_sentence(words_connector: ", ", two_words_connector: " y ", last_word_connector: " y ")
  end

  # Para pegar en el grupo de WhatsApp: título, fecha y lugar de cada cosa y un enlace. Nada personal.
  def texto_whatsapp(enlace)
    lineas = ["*#{titulo}*", ""]
    reuniones.each { lineas << "📅 #{_1.nombre} — #{cuando(_1.inicio)}#{" · #{_1.lugar}" if _1.lugar.present?}" }
    eventos.each { lineas << "🗓️ #{_1.titulo} — #{cuando(_1.inicio, todo_el_dia: _1.todo_el_dia)}#{" · #{_1.ubicacion}" if _1.ubicacion.present?}" }
    encuestas.each { lineas << "🗳️ Encuesta abierta: #{_1.titulo}" }
    lineas << "❓ Pregunta de la semana: «#{pregunta.contenido.squish.truncate(200)}»" if pregunta
    pidos = favores.count(&:pido?)
    ofertas = favores.size - pidos
    if favores.any?
      lineas << "🙋 #{[contar(pidos, 'pedido de ayuda', 'pedidos de ayuda'), contar(ofertas, 'oferta', 'ofertas')].compact.join(' y ')} entre vecinos"
    end
    lineas << "💬 #{contar(publicaciones, 'publicación nueva', 'publicaciones nuevas')} en el muro" if publicaciones.positive?
    lineas << "Esta semana no hay nada programado." if lineas.size == 2
    lineas += ["", "Confirma, vota y comenta en COMUNIA: #{enlace}"]
    lineas.join("\n")
  end

  def cuando(momento, todo_el_dia: false)
    dia = I18n.l(momento, format: "%A %-d de %B").capitalize
    todo_el_dia ? dia : "#{dia}, #{momento.strftime('%H:%M')}"
  end

  private

  def fin = ahora + DIAS.days

  def ids_organizacion = @ids_organizacion ||= [comunidad.id, *comunidad.logias.ids]

  def ids_cercanos
    @ids_cercanos ||= [comunidad.id, user && Miembro.where(user:, logia_id: ids_organizacion).pick(:logia_id)].compact.uniq
  end

  def muro
    propias = Publicacion.de_logias(ids_organizacion).where(created_at: (ahora - DIAS.days)..ahora)
    user ? propias.where.not(user:) : propias
  end

  def contar(n, singular, plural)
    return if n.zero?

    "#{n} #{n == 1 ? singular : plural}"
  end
end
