# Utilidades de las pruebas de la red de comunidades certificadas.
module RedPrueba
  CLAVE = "clave-larga-de-prueba".freeze

  def red_usuario(nombre = "Persona", perfil: true, **perfil_attrs)
    u = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(4)}@correo.co",
                     username: "r#{SecureRandom.hex(6)}", password: CLAVE, solo_red: true)
    red_perfil(u, **perfil_attrs) if perfil
    u
  end

  def red_perfil(user, **attrs)
    Red::Perfil.create!({ user: user, nombre_publico: user.nombre, acepto_tratamiento_at: Time.current,
                          politica_version: Red::POLITICA_VERSION, cuarentena_hasta: 1.day.ago }.merge(attrs))
  end

  def red_moderador
    rol = Rol.find_or_create_by!(codigo: "super_admin") { _1.nombre = "Super admin" }
    User.create!(nombre: "Mod", apellido: "Erador", email: "mod_#{SecureRandom.hex(4)}@correo.co", password: CLAVE,
                 rol: :super_admin, rol_ref: rol)
  end

  # Comunidad certificada hace `dias` días, con `miembros` personas verificadas hace `dias` días.
  def red_comunidad(nombre = "Comunidad #{SecureRandom.hex(3)}", miembros: [], dias: 365, estado: "certificada", **attrs)
    c = Red::Comunidad.create!({ nombre: nombre, tipo_vinculo: "club", criterio: "Socios activos del club con carné",
                                 estado: estado, certificada_at: (dias.days.ago if estado == "certificada") }.merge(attrs))
    miembros.each { |u| red_membresia(c, u, dias: dias) }
    c
  end

  def red_membresia(comunidad, user, dias: 365, por: nil, rol: "miembro", estado: "verificada")
    Red::Membresia.create!(comunidad: comunidad, user: user, estado: estado, rol: rol, verificada_por: por,
                           verificada_at: (dias.days.ago if estado == "verificada"),
                           vence_el: (1.year.from_now.to_date if estado == "verificada"))
  end

  def red_relleno(n) = Array.new(n) { |i| red_usuario("Relleno #{i}", perfil: false) }

  def red_publicacion(user, **attrs)
    Red::Publicacion.create!({ user: user, intencion: "ofrezco", categoria: "oficios", titulo: "Arreglo de neveras",
                               descripcion: "Reparo neveras y lavadoras a domicilio.", alcance: "publico",
                               publica_desde: 1.day.ago }.merge(attrs))
  end

  def red_entrar(user)
    sign_in user
  end

  # Quita lo que cambia en cada respuesta (nonce de CSP y token CSRF) para comparar dos cuerpos.
  def sin_aleatorios(html)
    html.gsub(/nonce="[^"]+"/, 'nonce=""').gsub(/(name="csrf-token" content=|name="csp-nonce" content=|name="authenticity_token" value=)"[^"]+"/, '\\1""')
  end

  # Cuenta las consultas SQL de un bloque (para comprobar que lo oculto y lo inexistente cuestan igual).
  def consultas_sql
    n = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, datos|
      n += 1 unless datos[:name].in?(["SCHEMA", "TRANSACTION"]) || datos[:sql].start_with?("BEGIN", "COMMIT", "SAVEPOINT", "RELEASE")
    end
    yield
    n
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end
end
