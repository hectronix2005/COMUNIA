# Datos de demostración de la Red COMUNIA. Todo es FICTICIO: personas, comunidades y correos
# (@ejemplo.invalid no existe). Se carga con `bin/rails red:demo` y nunca en producción.
abort "red:demo no se carga en producción" if Rails.env.production?

module RedDemo
  CLAVE = "demo-red-comunia".freeze
  DOMINIO = "ejemplo.invalid".freeze

  module_function

  def demo_usuario(nombre, apellido, **perfil)
    email = "#{I18n.transliterate(nombre).downcase}.#{I18n.transliterate(apellido).downcase}@#{DOMINIO}"
    u = User.find_or_initialize_by(email: email)
    u.assign_attributes(nombre: nombre, apellido: apellido, username: "demo#{I18n.transliterate(nombre + apellido).downcase.gsub(/[^a-z0-9]/, '')}",
                        password: CLAVE, solo_red: true)
    u.save!
    p = u.red_perfil || u.build_red_perfil
    p.assign_attributes({ nombre_publico: "#{nombre} #{apellido[0]}.", acepto_tratamiento_at: Time.current,
                          politica_version: Red::POLITICA_VERSION, cuarentena_hasta: 10.days.ago,
                          onboarding_completado_at: Time.current }.merge(perfil))
    p.save!
    u
  end

  def demo_comunidad(nombre, tipo, criterio, metodo, dias, **extra)
    Red::Comunidad.find_or_create_by!(nombre: nombre) do |c|
      c.assign_attributes(tipo_vinculo: tipo, criterio: criterio, metodo_verificacion: metodo, estado: "certificada",
                          certificada_at: dias.days.ago, evidencia: "Comunidad ficticia de demostración", **extra)
    end
  end

  def demo_miembro(comunidad, user, dias, rol: "miembro", por: nil)
    m = Red::Membresia.find_or_initialize_by(comunidad: comunidad, user: user)
    m.update!(estado: "verificada", rol: rol, verificada_por: por, verificada_at: dias.days.ago, vence_el: 1.year.from_now.to_date)
  end

  def demo_publicacion(user, titulo, **attrs)
    Red::Publicacion.find_or_create_by!(user: user, titulo: titulo) do |p|
      p.assign_attributes({ intencion: "ofrezco", categoria: "servicios", modalidad: "presencial", alcance: "publico",
                            descripcion: "#{titulo}. Publicación de demostración: no es una oferta real.",
                            publica_desde: 2.days.ago }.merge(attrs))
    end
  end

  def cargar
    personas = {
      lucia: demo_usuario("Lucía", "Montoya", titular: "Diseñadora gráfica", ciudad: "Medellín", alcance: "publico",
                          visible_publico: true, habilidades: "Identidad visual, ilustración, Figma",
                          contacto_correo: "lucia.contacto@#{DOMINIO}"),
      andres: demo_usuario("Andrés", "Quintero", titular: "Electricista certificado", ciudad: "Bogotá", alcance: "publico",
                           visible_publico: true, contacto_telefono: "3000000001"),
      sofia: demo_usuario("Sofía", "Restrepo", titular: "Estudiante de ingeniería de sistemas", ciudad: "Bogotá",
                          alcance: "publico", visible_publico: true, habilidades: "Python, SQL, clases de matemáticas"),
      mateo: demo_usuario("Mateo", "Gaviria", titular: "Busco empleo como auxiliar contable", ciudad: "Cali",
                          alcance: "mis_comunidades"),
      valeria: demo_usuario("Valeria", "Ospina", titular: "Arriendo habitación cerca a la universidad", ciudad: "Bogotá",
                            alcance: "mis_comunidades"),
      tomas: demo_usuario("Tomás", "Herrera", titular: "Profesor de guitarra", ciudad: "Medellín", alcance: "publico",
                          visible_publico: true)
    }
    relleno = Array.new(30) { |i| demo_usuario("Vecino", "Demo#{i + 1}") }

    club = demo_comunidad("Club Deportivo Los Ficticios", "club", "Socios con carné vigente del club", "documento", 400)
    uni = demo_comunidad("Universidad Imaginaria de Colombia", "universidad", "Estudiantes y egresados con correo @imaginaria.invalid",
                         "correo_institucional", 300, dominio_correo: "imaginaria.invalid")
    barrio = demo_comunidad("Conjunto Residencial El Ejemplo", "barrio", "Residentes del conjunto, comprobado por la administración",
                            "presencial", 200)

    admin_club = personas[:lucia]
    demo_miembro(club, admin_club, 380, rol: "administrador")
    [personas[:andres], personas[:tomas], personas[:mateo], *relleno.first(12)].each { demo_miembro(club, _1, 120, por: admin_club) }
    demo_miembro(uni, personas[:sofia], 250, rol: "administrador")
    [personas[:valeria], personas[:mateo], *relleno[10, 15]].each { demo_miembro(uni, _1, 90, por: personas[:sofia]) }
    demo_miembro(barrio, personas[:andres], 190, rol: "verificador")
    [personas[:lucia], personas[:valeria], *relleno.last(8)].each { demo_miembro(barrio, _1, 60, por: personas[:andres]) }
    [club, uni, barrio].each(&:recontar!)
    # Valeria solo se deja ver en la universidad, no en su conjunto residencial.
    valeria = personas[:valeria].red_perfil
    valeria.alcance = "elegidas"
    valeria.comunidades_elegidas = [uni.id]
    valeria.save!

    demo_publicacion(personas[:lucia], "Diseño logos e identidad para emprendimientos", categoria: "servicios", modalidad: "remoto",
                     precio_texto: "Desde $300.000")
    demo_publicacion(personas[:andres], "Instalaciones eléctricas y revisión RETIE", categoria: "oficios", ciudad: "Bogotá")
    demo_publicacion(personas[:sofia], "Clases de cálculo y programación", categoria: "formacion", modalidad: "mixto",
                     precio_texto: "$40.000 la hora")
    demo_publicacion(personas[:tomas], "Clases de guitarra para principiantes", categoria: "formacion", ciudad: "Medellín")
    demo_publicacion(personas[:mateo], "Busco empleo como auxiliar contable", intencion: "necesito", categoria: "empleo",
                     ciudad: "Cali", alcance: "mis_comunidades")
    pub = Red::Publicacion.find_by(user: personas[:valeria], titulo: "Arriendo habitación amoblada")
    unless pub
      pub = Red::Publicacion.new(user: personas[:valeria], titulo: "Arriendo habitación amoblada", intencion: "ofrezco",
                                 categoria: "vivienda", modalidad: "presencial", ciudad: "Bogotá", alcance: "elegidas",
                                 descripcion: "Habitación amoblada a diez minutos de la universidad. Publicación de demostración.")
      pub.comunidades_elegidas = [uni.id]
      pub.save!
    end
    demo_publicacion(personas[:andres], "Necesito quien pinte un apartamento", intencion: "necesito", categoria: "oficios",
                     alcance: "mis_comunidades")

    Red::CalculoConfianza.recalcular_todo!
    puts "Red COMUNIA (demo): #{Red::Comunidad.count} comunidades, #{Red::Perfil.count} perfiles, " \
         "#{Red::Publicacion.count} publicaciones. Entra con lucia.montoya@#{DOMINIO} / #{CLAVE}"
  end
end unless defined?(RedDemo)

RedDemo.cargar
