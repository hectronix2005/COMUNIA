require "open-uri"

root = Logia.find(6) # FREEMASONS
logia_ids = [root.id] + root.logias.pluck(:id)
users = User.where(logia_id: logia_ids).to_a
raise "Sin usuarios" if users.empty?

puts "Seeding marketplace para tenant FREEMASONS (#{users.size} usuarios disponibles)"

UNSPLASH_SEEDS = {
  producto: %w[laptop phone camera watch book bicycle headphones plant],
  servicio: %w[office meeting construction legal medical teaching truck finance],
  empleo:   %w[office team workspace computer interview]
}

def fetch_image(seed)
  url = "https://picsum.photos/seed/#{seed}/800/600"
  URI.open(url, read_timeout: 10).read
rescue => e
  puts "  [img] skip #{seed}: #{e.class}"
  nil
end

def attach_image(anuncio, seed, filename)
  data = fetch_image(seed)
  return unless data
  anuncio.imagenes.attach(
    io: StringIO.new(data),
    filename: "#{filename}.jpg",
    content_type: "image/jpeg"
  )
end

datos = [
  # ── SERVICIOS ────────────────────────────────────────────────
  { tipo: "servicio", titulo: "Asesoría legal en derecho corporativo", categoria: "Legal",
    descripcion: "Abogado con 15 años de experiencia en sociedades, contratos y resolución de disputas. Primera consulta gratuita.",
    precio: 150_000, moneda: "COP", contacto: "3001234567", ubicacion: "Bogotá, Colombia",
    latitud: 4.6097, longitud: -74.0817, estado: "disponible", seed: "legal1" },
  { tipo: "servicio", titulo: "Consultoría tecnológica para PyMEs", categoria: "Tecnología",
    descripcion: "Implementación de sistemas, migración a la nube, y automatización de procesos. Tarifas por hora o proyecto.",
    precio: 180_000, moneda: "COP", contacto: "consultor@tech.co", ubicacion: "Medellín, Colombia",
    latitud: 6.2442, longitud: -75.5812, estado: "disponible", seed: "tech1" },
  { tipo: "servicio", titulo: "Clases particulares de matemáticas", categoria: "Educación",
    descripcion: "Refuerzo escolar para bachillerato y universidad. Cálculo, álgebra, estadística.",
    precio: 60_000, moneda: "COP", contacto: "profe.mat@mail.com", ubicacion: "Cali, Colombia",
    latitud: 3.4516, longitud: -76.5320, estado: "disponible", seed: "edu1" },
  { tipo: "servicio", titulo: "Fisioterapia a domicilio", categoria: "Salud",
    descripcion: "Terapia física para adultos mayores, recuperación post-quirúrgica y lesiones deportivas.",
    precio: 90_000, moneda: "COP", contacto: "3109876543", ubicacion: "Barranquilla",
    estado: "reservado", seed: "salud1" },
  { tipo: "servicio", titulo: "Remodelación y construcción en seco", categoria: "Construcción",
    descripcion: "Drywall, cielorrasos, baños, cocinas. Presupuestos sin compromiso.",
    precio: 250_000, moneda: "COP", contacto: "obrasliv@mail.com", ubicacion: "Bogotá, Colombia",
    latitud: 4.7110, longitud: -74.0721, estado: "disponible", seed: "construct1" },
  { tipo: "servicio", titulo: "Servicio de transporte y mudanzas", categoria: "Transporte",
    descripcion: "Camión NPR con dos auxiliares. Cubrimos todo Bogotá y municipios cercanos.",
    precio: 200_000, moneda: "COP", contacto: "3155551234", ubicacion: "Bogotá D.C.",
    estado: "disponible", seed: "transport1" },
  { tipo: "servicio", titulo: "Contabilidad y declaración de renta", categoria: "Finanzas",
    descripcion: "Contador público titulado. Servicios mensuales y asesoría tributaria personal.",
    precio: 120_000, moneda: "COP", contacto: "contador@pro.co", ubicacion: "Bucaramanga",
    estado: "disponible", seed: "finanzas1" },

  # ── PRODUCTOS ────────────────────────────────────────────────
  { tipo: "producto", titulo: "MacBook Pro 14\" M3 Pro - como nuevo", categoria: "Electrónica",
    descripcion: "MacBook Pro 2023, 18GB RAM, 512GB SSD. Poco uso, con caja y cargador original. Batería al 98%.",
    precio: 8_500_000, moneda: "COP", contacto: "vende@mac.co", ubicacion: "Bogotá",
    latitud: 4.6586, longitud: -74.0939, estado: "disponible", seed: "laptop1" },
  { tipo: "producto", titulo: "iPhone 14 Pro 256GB Morado", categoria: "Electrónica",
    descripcion: "Sin rayones, con funda y vidrio templado. Todos los accesorios originales.",
    precio: 3_200_000, moneda: "COP", contacto: "3102223344", ubicacion: "Medellín",
    estado: "reservado", seed: "phone1" },
  { tipo: "producto", titulo: "Sofá modular en L - 4 puestos", categoria: "Hogar",
    descripcion: "Tela gris oscuro, estructura de madera maciza. 2.8m x 1.8m. Motivo de venta: trasteo.",
    precio: 1_800_000, moneda: "COP", contacto: "3204445566", ubicacion: "Bogotá",
    estado: "disponible", seed: "sofa1" },
  { tipo: "producto", titulo: "Bicicleta de ruta Specialized Allez", categoria: "Deportes",
    descripcion: "Talla 54, grupo Shimano 105, llantas 700c. Mantenimiento reciente.",
    precio: 2_400_000, moneda: "COP", contacto: "bike@sale.co", ubicacion: "Medellín",
    latitud: 6.2087, longitud: -75.5636, estado: "disponible", seed: "bike1" },
  { tipo: "producto", titulo: "Cámara Sony A7 III + lente 24-70 f/2.8", categoria: "Electrónica",
    descripcion: "Kit profesional para fotografía y video. Menos de 15.000 disparos.",
    precio: 9_500_000, moneda: "COP", contacto: "3001112233", ubicacion: "Cartagena",
    estado: "disponible", seed: "camera1" },
  { tipo: "producto", titulo: "Colección de libros de masonería (12 tomos)", categoria: "Libros",
    descripcion: "Obra completa en tapa dura. Excelente estado, ideal para bibliotecas.",
    precio: 950_000, moneda: "COP", contacto: "libros@mail.com", ubicacion: "Bogotá",
    estado: "vendido", seed: "books1" },
  { tipo: "producto", titulo: "Pintura al óleo original - paisaje andino", categoria: "Arte",
    descripcion: "Obra firmada, 80x60cm, enmarcada. Ideal para sala o estudio.",
    precio: 1_200_000, moneda: "COP", contacto: "arte@pintor.co", ubicacion: "Bogotá",
    estado: "disponible", seed: "art1" },
  { tipo: "producto", titulo: "Toyota Corolla 2019 - único dueño", categoria: "Vehículos",
    descripcion: "48.000 km, mantenimientos al día en concesionario. Pase a tu nombre incluido.",
    precio: 62_000_000, moneda: "COP", contacto: "3167778899", ubicacion: "Cali",
    estado: "disponible", seed: "car1" },
  { tipo: "producto", titulo: "Chaqueta de cuero genuino - talla M", categoria: "Moda",
    descripcion: "Cuero nappa, forro térmico. Usada 2 veces. Precio original $1.200.000.",
    precio: 450_000, moneda: "COP", contacto: "3015557788", ubicacion: "Bogotá",
    estado: "pausado", seed: "jacket1" },

  # ── EMPLEOS ──────────────────────────────────────────────────
  { tipo: "empleo", titulo: "Desarrollador Full-Stack Ruby on Rails", categoria: "Tiempo completo",
    descripcion: "Startup fintech busca dev con 3+ años en Rails, PostgreSQL, Stimulus/Turbo. Remoto Colombia. Paquete competitivo.",
    precio: nil, contacto: "jobs@fintech.co", ubicacion: "Remoto",
    estado: "disponible", seed: "dev1" },
  { tipo: "empleo", titulo: "Asistente administrativa medio tiempo", categoria: "Medio tiempo",
    descripcion: "Manejo de agenda, archivo, atención a clientes. Lunes a viernes 8am-1pm. Zona norte Bogotá.",
    precio: nil, contacto: "rrhh@oficina.co", ubicacion: "Bogotá, Chapinero",
    latitud: 4.6482, longitud: -74.0614, estado: "disponible", seed: "admin1" },
  { tipo: "empleo", titulo: "Diseñador gráfico freelance", categoria: "Freelance",
    descripcion: "Necesitamos diseño de identidad para 3 marcas. Pago por proyecto. Portafolio requerido.",
    precio: nil, contacto: "design@brand.co", ubicacion: "Remoto",
    estado: "disponible", seed: "design1" },
  { tipo: "empleo", titulo: "Practicante de marketing digital", categoria: "Prácticas",
    descripcion: "Estudiante últimos semestres, manejo de redes sociales y Google Ads. 6 meses con opción de contratación.",
    precio: nil, contacto: "practicas@marketing.co", ubicacion: "Medellín",
    estado: "disponible", seed: "marketing1" },
  { tipo: "empleo", titulo: "Contador senior - industria manufacturera", categoria: "Tiempo completo",
    descripcion: "Experiencia mínima 5 años, manejo NIIF e impuestos. Salario $6-8M + beneficios.",
    precio: nil, contacto: "seleccion@manufac.co", ubicacion: "Cali, Yumbo",
    estado: "disponible", seed: "cont1" },
  { tipo: "empleo", titulo: "Conductor de vehículo utilitario (licencia C2)", categoria: "Tiempo completo",
    descripcion: "Rutas urbanas Bogotá. Horario 6am-3pm. Prestaciones de ley.",
    precio: nil, contacto: "logistica@transp.co", ubicacion: "Bogotá",
    estado: "pausado", seed: "driver1" }
]

creados = 0
datos.each_with_index do |d, i|
  autor = users[i % users.size]
  logia_asignada = Logia.find(autor.logia_id || root.id)
  anuncio = NegocioAnuncio.new(
    titulo:      d[:titulo],
    descripcion: d[:descripcion],
    tipo:        d[:tipo],
    categoria:   d[:categoria],
    precio:      d[:precio],
    moneda:      d[:moneda] || "COP",
    contacto:    d[:contacto],
    ubicacion:   d[:ubicacion],
    latitud:     d[:latitud],
    longitud:    d[:longitud],
    estado:      d[:estado] || "disponible",
    activo:      true,
    user:        autor,
    logia:       logia_asignada
  )
  if anuncio.save
    attach_image(anuncio, d[:seed], d[:titulo].parameterize) if d[:seed]
    creados += 1
    print "."
  else
    puts "  [fail] #{d[:titulo]}: #{anuncio.errors.full_messages.join(', ')}"
  end
end
puts "\nCreados: #{creados} anuncios"

# Variar vistas para probar orden "populares"
NegocioAnuncio.where(logia_id: logia_ids).find_each do |a|
  NegocioAnuncio.where(id: a.id).update_all(vistas_count: rand(0..250))
end

# Favoritos de ejemplo
sample_user = users.first
NegocioAnuncio.where(logia_id: logia_ids).order("RANDOM()").limit(6).each do |a|
  NegocioFavorito.find_or_create_by(user: sample_user, negocio_anuncio: a)
end
puts "Favoritos del user '#{sample_user.username}': #{sample_user.negocio_favoritos.count}"

# Una conversación de ejemplo
anuncio = NegocioAnuncio.where(logia_id: logia_ids).where.not(user_id: sample_user.id).first
if anuncio && sample_user
  conv = NegocioConversacion.find_or_create_by(negocio_anuncio: anuncio, comprador: sample_user) { |c| c.vendedor = anuncio.user }
  if conv.mensajes.empty?
    conv.mensajes.create!(user: sample_user, cuerpo: "Hola, ¿sigue disponible?")
    conv.mensajes.create!(user: anuncio.user, cuerpo: "Hola, sí. ¿Te interesa coordinar una visita?")
    conv.mensajes.create!(user: sample_user, cuerpo: "Perfecto, ¿qué tal mañana en la tarde?")
  end
  puts "Conversación demo: #{conv.id} (#{conv.mensajes.count} mensajes)"
end

puts "\n✅ Seed completado"
puts "Total anuncios del tenant: #{NegocioAnuncio.where(logia_id: logia_ids).count}"
