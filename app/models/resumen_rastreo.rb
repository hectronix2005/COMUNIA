# Resumen de un día del rastreo de pruebas (config/initializers/ahoy.rb): quién entró, cuánto estuvo y hasta
# dónde llegó, quién abrió su invitación sin aceptarla, quién no ha entrado y qué errores hubo. Lo manda
# ResumenRastreoJob a los superadmins a las 9 p. m. (Héctor, 1-nov-2026) y lo pinta /rastreo, día por día.
# No cuenta a los superadmins (son quienes lo leen) ni las cuentas de RASTREO_SIN_CONTAR: hneira es la de Héctor,
# y sus visitas se mezclaban con las de family and friends (1-nov-2026).
class ResumenRastreo
  MAX_PAGINAS = 4
  MAX_ERRORES = 3

  # Usernames separados por comas; sin la variable, hneira.
  def self.usernames_sin_contar = ENV.fetch("RASTREO_SIN_CONTAR", "hneira").split(",").map(&:strip).compact_blank

  # Quienes no cuentan en el rastreo: los superadmins y las cuentas de RASTREO_SIN_CONTAR.
  def self.sin_contar
    con_rol = User.left_joins(:rol_ref)
    con_rol.where(roles: { codigo: "super_admin" }).or(con_rol.where(username: usernames_sin_contar)).select(:id)
  end

  attr_reader :fecha

  def initialize(fecha = Time.zone.today)
    @fecha = fecha
  end

  def vacio? = personas.empty? && invitaciones_abiertas.empty?

  def titulo
    gente = personas.size + invitaciones_abiertas.size
    fallos = errores.size
    "Rastreo de #{fecha == Time.zone.today ? 'hoy' : I18n.l(fecha, format: :short)}: " \
      "#{gente} #{gente == 1 ? 'persona' : 'personas'}, " \
      "#{fallos.zero? ? 'sin errores' : "#{fallos} #{fallos == 1 ? 'error' : 'errores'}"}"
  end

  def lineas
    lineas = personas.map do |p|
      visitas = "#{p[:visitas]} #{p[:visitas] == 1 ? 'visita' : 'visitas'}"
      llego = " llegó a #{enumerar(p[:paginas])}." if p[:paginas].any?
      "#{nombre(p[:user])}: #{visitas}, #{duracion(p[:segundos])};#{llego || ' sin páginas.'}"
    end
    invitaciones_abiertas.each do |user, segundos|
      lineas << "#{nombre(user)}: abrió la invitación, no la aceptó; #{duracion(segundos)}."
    end
    if sin_entrar.any?
      lineas << "Sin entrar: #{enumerar(sin_entrar.map { nombre(_1) })} (#{sin_entrar.one? ? 'invitación pendiente' : 'invitaciones pendientes'})."
    end
    if errores.any?
      vistos = errores.map { |e| "#{e[:que]} (#{e[:quien]})" }.uniq
      extra = vistos.size > MAX_ERRORES ? " y #{vistos.size - MAX_ERRORES} más" : ""
      lineas << "#{errores.size} #{errores.one? ? 'error' : 'errores'}: #{vistos.first(MAX_ERRORES).join('; ')}#{extra}."
    end
    lineas
  end

  def cuerpo = lineas.join("\n")

  # Quienes tuvieron sesión ese día, con sus visitas, el tiempo a la vista y las páginas, en el orden en que
  # llegaron a ellas.
  def personas
    @personas ||= visitas.select(&:user_id).group_by(&:user).map do |user, suyas|
      suyos = suyas.flat_map { eventos(_1) }
      { user:, visitas: suyas.size, segundos: segundos(suyos), paginas: paginas(suyos) }
    end.sort_by { -_1[:segundos] }
  end

  # Invitaciones abiertas sin sesión (InvitacionesController apunta a quién era) y sin aceptar ese día.
  def invitaciones_abiertas
    @invitaciones_abiertas ||= begin
      anonimas = visitas.reject(&:user_id)
      por_invitado = anonimas.each_with_object(Hash.new { |h, k| h[k] = [] }) do |visita, acc|
        id = eventos(visita).filter_map { _1.properties["invitado_id"] }.first
        acc[id] << visita if id
      end
      con_sesion = personas.map { _1[:user].id }
      User.where(id: por_invitado.keys - con_sesion).map { |u| [u, segundos(por_invitado[u.id].flat_map { eventos(_1) })] }
    end
  end

  # Invitaciones vigentes sin aceptar de quien ese día no apareció. Los enlaces se generan sin correo
  # (skip_invitation), así que la fecha es invitation_created_at: invitation_sent_at queda vacío.
  def sin_entrar
    @sin_entrar ||= User.invitation_not_accepted.where.not(invitation_token: nil)
                        .where(invitation_created_at: User.invite_for.ago(fin)..fin)
                        .where.not(id: self.class.sin_contar).where.not(id: invitaciones_abiertas.map { _1.first.id } + personas.map { _1[:user].id })
                        .order(:nombre).to_a
  end

  def errores
    @errores ||= visitas.flat_map do |visita|
      quien = visita.user ? nombre(visita.user) : "sin sesión"
      eventos(visita).select { error?(_1) }.map do |e|
        p = e.properties
        que = e.name == "Petición" ? "#{p['estado']} en #{p['ruta']}" : "#{p['tipo'] == 'script' ? 'JS' : p['tipo']} en #{p['page']}"
        { que:, quien: }
      end
    end
  end

  private

  def inicio = fecha.in_time_zone.beginning_of_day
  def fin = fecha.in_time_zone.end_of_day

  def visitas
    @visitas ||= begin
      Ahoy::Visit.where(id: Ahoy::Event.where(time: inicio..fin).select(:visit_id))
                 .where("ahoy_visits.user_id IS NULL OR ahoy_visits.user_id NOT IN (?)", self.class.sin_contar)
                 .includes(:user).to_a
    end
  end

  # Los eventos de una visita que caen en el día (una visita puede pasar la medianoche).
  def eventos(visita)
    @eventos ||= Ahoy::Event.where(visit_id: visitas.map(&:id), time: inicio..fin).order(:time).group_by(&:visit_id)
    @eventos.fetch(visita.id, [])
  end

  def error?(evento)
    evento.name.in?(Ahoy::Event::ERRORES) || (evento.name == "Petición" && evento.properties["estado"].to_i >= 500)
  end

  def segundos(lista)
    lista.select { _1.name == "Tiempo en vista" }.sum { _1.properties["segundos_visible"].to_i }
  end

  # El nombre de cada pantalla sale de su título («Calendario — FREEMASONS» → «Calendario»).
  def paginas(lista)
    lista.select { _1.name == "$view" }.sort_by(&:time)
           .filter_map { _1.properties["title"].to_s.split(/ [—·|] /).first.presence }.uniq
  end

  def enumerar(cosas)
    cosas = cosas.first(MAX_PAGINAS) + ["#{cosas.size - MAX_PAGINAS} más"] if cosas.size > MAX_PAGINAS
    cosas.to_sentence(words_connector: ", ", two_words_connector: " y ", last_word_connector: " y ")
  end

  def nombre(user) = user.nombre.to_s.split.first.presence || user.username

  def duracion(segundos)
    segundos < 60 ? "#{segundos} s" : "#{(segundos / 60.0).round} min"
  end
end
