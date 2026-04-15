puts "Creando datos de ejemplo..."

# === PERMISOS ===
permisos_data = [
  # Logias
  { recurso: "logias", accion: "index", descripcion: "Ver listado de logias" },
  { recurso: "logias", accion: "show", descripcion: "Ver detalle de logia" },
  { recurso: "logias", accion: "create", descripcion: "Crear logias" },
  { recurso: "logias", accion: "update", descripcion: "Editar logias" },
  { recurso: "logias", accion: "destroy", descripcion: "Eliminar logias" },
  { recurso: "logias", accion: "gestionar_conceptos", descripcion: "Gestionar conceptos de cobro de la logia" },
  # Miembros
  { recurso: "miembros", accion: "index", descripcion: "Ver listado de miembros" },
  { recurso: "miembros", accion: "show", descripcion: "Ver detalle de miembro" },
  { recurso: "miembros", accion: "create", descripcion: "Crear miembros" },
  { recurso: "miembros", accion: "update", descripcion: "Editar miembros" },
  { recurso: "miembros", accion: "destroy", descripcion: "Eliminar miembros" },
  # Periodos
  { recurso: "periodos", accion: "index", descripcion: "Ver listado de periodos" },
  { recurso: "periodos", accion: "show", descripcion: "Ver detalle de periodo" },
  { recurso: "periodos", accion: "create", descripcion: "Crear periodos" },
  { recurso: "periodos", accion: "update", descripcion: "Editar periodos" },
  { recurso: "periodos", accion: "destroy", descripcion: "Eliminar periodos" },
  { recurso: "periodos", accion: "generar_cobros", descripcion: "Generar cobros de un periodo" },
  # Cobros
  { recurso: "cobros", accion: "index", descripcion: "Ver listado de cobros" },
  { recurso: "cobros", accion: "show", descripcion: "Ver detalle de cobro" },
  { recurso: "cobros", accion: "adjuntar_soporte", descripcion: "Adjuntar soporte de pago" },
  { recurso: "cobros", accion: "validar", descripcion: "Validar pagos" },
  { recurso: "cobros", accion: "confirmar_pago", descripcion: "Confirmar pagos" },
  { recurso: "cobros", accion: "rechazar_pago", descripcion: "Rechazar pagos" },
  # Reportes
  { recurso: "reportes", accion: "cartera", descripcion: "Ver reporte de cartera" },
  { recurso: "reportes", accion: "recaudacion", descripcion: "Ver reporte de recaudacion" },
  { recurso: "reportes", accion: "morosos", descripcion: "Ver reporte de morosos" },
  { recurso: "reportes", accion: "recibo", descripcion: "Ver recibo de caja" },
  # Conceptos
  { recurso: "conceptos", accion: "index", descripcion: "Ver listado de conceptos" },
  { recurso: "conceptos", accion: "show", descripcion: "Ver detalle de concepto" },
  { recurso: "conceptos", accion: "create", descripcion: "Crear conceptos" },
  { recurso: "conceptos", accion: "update", descripcion: "Editar conceptos" },
  { recurso: "conceptos", accion: "destroy", descripcion: "Eliminar conceptos" },
  # Roles
  { recurso: "roles", accion: "index", descripcion: "Ver listado de roles" },
  { recurso: "roles", accion: "show", descripcion: "Ver detalle de rol" },
  { recurso: "roles", accion: "create", descripcion: "Crear roles" },
  { recurso: "roles", accion: "update", descripcion: "Editar roles" },
  { recurso: "roles", accion: "destroy", descripcion: "Eliminar roles" },
  { recurso: "roles", accion: "gestionar_permisos", descripcion: "Asignar/quitar permisos a roles" }
]

permisos_data.each do |data|
  Permiso.find_or_create_by!(recurso: data[:recurso], accion: data[:accion]) do |p|
    p.descripcion = data[:descripcion]
  end
end
puts "  #{Permiso.count} permisos creados"

# === ROLES DE SISTEMA ===
todos_los_permisos = Permiso.all

# Super Admin - todos los permisos (aunque ya tiene bypass)
rol_super_admin = Rol.find_or_create_by!(codigo: "super_admin") do |r|
  r.nombre = "Super Admin"
  r.descripcion = "Acceso total al sistema"
  r.es_sistema = true
end
rol_super_admin.permisos = todos_los_permisos

# Admin Logia - permisos de gestion de su logia
rol_admin_logia = Rol.find_or_create_by!(codigo: "admin_logia") do |r|
  r.nombre = "Admin Logia"
  r.descripcion = "Administrador de una logia especifica"
  r.es_sistema = true
end

permisos_admin = Permiso.where(
  recurso: "miembros", accion: ["index", "show", "create", "update", "destroy"]
).or(Permiso.where(
  recurso: "logias", accion: ["show", "gestionar_conceptos"]
)).or(Permiso.where(
  recurso: "periodos", accion: ["index", "show"]
)).or(Permiso.where(
  recurso: "cobros", accion: ["index", "show", "validar", "confirmar_pago", "rechazar_pago"]
)).or(Permiso.where(
  recurso: "reportes", accion: ["cartera", "recaudacion", "morosos", "recibo"]
)).or(Permiso.where(
  recurso: "conceptos", accion: ["index", "show", "create", "update", "destroy"]
))
rol_admin_logia.permisos = permisos_admin

# Miembro - permisos basicos
rol_miembro = Rol.find_or_create_by!(codigo: "miembro") do |r|
  r.nombre = "Miembro"
  r.descripcion = "Miembro regular de una logia"
  r.es_sistema = true
end

permisos_miembro = Permiso.where(
  recurso: "cobros", accion: ["adjuntar_soporte"]
)
rol_miembro.permisos = permisos_miembro

puts "  #{Rol.count} roles creados"

# === MIGRAR USUARIOS EXISTENTES ===
User.where(rol_ref_id: nil).find_each do |u|
  caso = case u.rol
         when "super_admin" then rol_super_admin
         when "admin_logia" then rol_admin_logia
         else rol_miembro
         end
  u.update_column(:rol_ref_id, caso.id)
end
puts "  Usuarios migrados a roles dinamicos"

# === LOGIAS ===
logias_data = [
  { nombre: "Logia Luz del Oriente", codigo: "LOG001" },
  { nombre: "Logia Estrella del Sur", codigo: "LOG002" },
  { nombre: "Logia Fraternidad Universal", codigo: "LOG003" }
]

logias = logias_data.map do |data|
  Logia.find_or_create_by!(codigo: data[:codigo]) do |l|
    l.nombre = data[:nombre]
  end
end
puts "  #{Logia.count} logias creadas"

# Super Admin
super_admin = User.find_or_create_by!(email: "admin@granlogia.co") do |u|
  u.nombre = "Gran"
  u.apellido = "Maestro"
  u.password = "password123"
  u.rol = :super_admin
  u.rol_ref = rol_super_admin
end
super_admin.update_column(:rol_ref_id, rol_super_admin.id) if super_admin.rol_ref_id.nil?
puts "  Super Admin: admin@granlogia.co / password123"

# Admin por logia
admins = logias.map.with_index do |logia, i|
  admin = User.find_or_create_by!(email: "admin#{i + 1}@granlogia.co") do |u|
    u.nombre = "Admin"
    u.apellido = "Logia #{logia.codigo}"
    u.password = "password123"
    u.rol = :admin_logia
    u.logia = logia
    u.rol_ref = rol_admin_logia
  end
  admin.update_column(:rol_ref_id, rol_admin_logia.id) if admin.rol_ref_id.nil?
  admin
end
puts "  #{admins.count} admins de logia creados"

# Miembros (5 por logia)
contador = 0
logias.each_with_index do |logia, li|
  5.times do |i|
    num = li * 5 + i + 1
    user = User.find_or_create_by!(email: "miembro#{num}@granlogia.co") do |u|
      u.nombre = "Miembro"
      u.apellido = "#{num.to_s.rjust(3, '0')}"
      u.password = "password123"
      u.rol = :miembro
      u.logia = logia
      u.rol_ref = rol_miembro
    end
    user.update_column(:rol_ref_id, rol_miembro.id) if user.rol_ref_id.nil?

    Miembro.find_or_create_by!(user: user) do |m|
      m.logia = logia
      m.numero_miembro = "M#{num.to_s.rjust(4, '0')}"
      m.cedula = "10000000#{num.to_s.rjust(2, '0')}"
      m.grado = ["Aprendiz", "Companero", "Maestro"].sample
      m.estado = :activo
    end
    contador += 1
  end
end
puts "  #{contador} miembros creados"

# Conceptos de cobro por logia
conceptos_base = [
  { nombre: "Aporte Gran Logia", descripcion: "Contribucion mensual a la Gran Logia", orden: 1 },
  { nombre: "Cuota Logia", descripcion: "Sostenimiento del taller", orden: 2 },
  { nombre: "Fondo de Solidaridad", descripcion: "Fondo para apoyo entre hermanos", orden: 3 },
  { nombre: "Fondo Hospitalario", descripcion: "Fondo de beneficencia", orden: 4 }
]

montos_por_logia = {
  "LOG001" => [50_000, 70_000, 20_000, 10_000],
  "LOG002" => [50_000, 60_000, 15_000, 10_000],
  "LOG003" => [50_000, 80_000, 25_000, 15_000]
}

logias.each do |logia|
  montos = montos_por_logia[logia.codigo]
  conceptos_base.each_with_index do |concepto_data, i|
    ConceptoCobro.find_or_create_by!(logia: logia, nombre: concepto_data[:nombre]) do |c|
      c.monto = montos[i]
      c.descripcion = concepto_data[:descripcion]
      c.orden = concepto_data[:orden]
      c.activo = true
    end
  end
  puts "  Logia #{logia.codigo}: cuota mensual $#{logia.monto_mensual.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1.')}"
end

# Periodo de cobro actual
periodo = PeriodoCobro.find_or_create_by!(anio: 2026, mes: 3) do |p|
  p.monto = 150_000
  p.fecha_vencimiento = Date.new(2026, 3, 31)
  p.creado_por = super_admin
end
puts "  Periodo: #{periodo.nombre}"

# Generar cobros
periodo.generar_cobros!
puts "  #{periodo.cobros.count} cobros generados"

puts "\nDatos de ejemplo creados exitosamente!"
puts "Login Super Admin: admin@granlogia.co / password123"
puts "Login Admin Logia: admin1@granlogia.co / password123"
puts "Login Miembro: miembro1@granlogia.co / password123"
