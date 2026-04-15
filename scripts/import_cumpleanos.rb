require "csv"

CSV_PATH = "/tmp/cumpleanos_lf.csv"
TENANT_LOGIA_IDS = [6, 1, 9]

MESES = {
  "enero" => 1, "febrero" => 2, "marzo" => 3, "abril" => 4, "mayo" => 5, "junio" => 6,
  "julio" => 7, "agosto" => 8, "septiembre" => 9, "setiembre" => 9, "octubre" => 10,
  "noviembre" => 11, "diciembre" => 12,
  "ene" => 1, "feb" => 2, "mar" => 3, "abr" => 4, "jun" => 6, "jul" => 7,
  "ago" => 8, "sep" => 9, "sept" => 9, "oct" => 10, "nov" => 11, "dic" => 12
}

def normalize(s)
  return "" if s.nil?
  s.to_s.strip.downcase
    .unicode_normalize(:nfd).gsub(/[\u0300-\u036f]/, "")
    .gsub(/[^a-z0-9 ]/, " ")
    .squeeze(" ")
end

def levenshtein(a, b)
  a, b = a.to_s, b.to_s
  m, n = a.length, b.length
  return n if m.zero?
  return m if n.zero?
  prev = (0..n).to_a
  (1..m).each do |i|
    curr = [i]
    (1..n).each do |j|
      cost = a[i - 1] == b[j - 1] ? 0 : 1
      curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].min
    end
    prev = curr
  end
  prev[n]
end

STOPWORDS = %w[de la los las del el y].freeze

# Similaridad ponderada: overlap de tokens + similitud global
def similarity(norm_a, norm_b)
  return 1.0 if norm_a == norm_b
  tokens_a = norm_a.split(/\s+/).reject { |t| t.empty? || STOPWORDS.include?(t) }
  tokens_b = norm_b.split(/\s+/).reject { |t| t.empty? || STOPWORDS.include?(t) }
  return 0.0 if tokens_a.empty? || tokens_b.empty?

  comunes = (tokens_a & tokens_b).size

  # Overlap coefficient: premia cuando todos los tokens del más corto están en el más largo
  overlap = comunes.to_f / [tokens_a.size, tokens_b.size].min

  # Jaccard (símétrico)
  jaccard = comunes.to_f / (tokens_a | tokens_b).size

  # Levenshtein normalizado entre strings completos (ignorando espacios)
  s_a = norm_a.delete(" ")
  s_b = norm_b.delete(" ")
  lev = levenshtein(s_a, s_b)
  sim_lev = 1.0 - (lev.to_f / [s_a.length, s_b.length].max)

  # 50% overlap + 25% jaccard + 25% similitud de caracteres
  (overlap * 0.5) + (jaccard * 0.25) + (sim_lev * 0.25)
end

def mejor_coincidencia(nombre_norm, mapa)
  best_m = nil
  best_score = 0.0
  mapa.each do |k, m|
    s = similarity(nombre_norm, k)
    if s > best_score
      best_score = s
      best_m = m
    end
  end
  [best_m, best_score]
end

def parse_fecha(raw)
  return nil if raw.blank?
  txt = raw.to_s.strip.downcase
  return nil if txt.empty?

  # dd/mm/yyyy | d/m/yyyy | dd-mm-yyyy
  if (m = txt.match(%r{\A(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\z}))
    d, mo, y = m[1].to_i, m[2].to_i, m[3].to_i
    y = 2000 + y if y < 100
    y = 1999 if y < 1900 && y > 0  # corrige "0999" → 1999
    return Date.new(y, mo, d) rescue nil
  end

  # dd/mm (sin año)
  if (m = txt.match(%r{\A(\d{1,2})[/\-.](\d{1,2})\z}))
    return Date.new(2000, m[2].to_i, m[1].to_i) rescue nil
  end

  # "10 DE ABRIL" | "10 abril" | "15 Diciembre"
  if (m = txt.match(/\A(\d{1,2})\s+(?:de\s+)?([a-záéíóúñ]+)\z/))
    mes = MESES[m[2]]
    return Date.new(2000, mes, m[1].to_i) if mes
  end

  # "ABRIL 10" | "Noviembre 9"
  if (m = txt.match(/\A([a-záéíóúñ]+)\s+(?:de\s+)?(\d{1,2})\z/))
    mes = MESES[m[1]]
    return Date.new(2000, mes, m[2].to_i) if mes
  end

  # "10 DE ABRIL DE 1985"
  if (m = txt.match(/\A(\d{1,2})\s+de\s+([a-záéíóúñ]+)\s+(?:de\s+)?(\d{4})\z/))
    mes = MESES[m[2]]
    return Date.new(m[3].to_i, mes, m[1].to_i) if mes
  end

  nil
rescue Date::Error
  nil
end

def infer_parentesco_hijo(nombre)
  return "Otro" if nombre.blank?
  primer = nombre.strip.split(/\s+/).first.to_s.downcase
  femeninas = %w[a o]  # suffix vowels heuristic
  last = primer[-1]
  # Names ending in 'a' are typically feminine in Spanish
  return "Hija" if last == "a"
  # Common feminine names ending in other letters
  femeninas_esp = %w[maria mariana isabel paula valentina ana luisa shaneida gabriela julieta violeta diana natalia]
  return "Hija" if femeninas_esp.include?(primer)
  "Hijo"
end

csv = CSV.read(CSV_PATH, headers: true, liberal_parsing: true)
puts "Filas CSV: #{csv.size}"

miembros = Miembro.where(logia_id: TENANT_LOGIA_IDS).includes(:user).to_a
puts "Miembros del tenant: #{miembros.size}"

mapa_miembros = miembros.map { |m| [normalize(m.user.nombre_completo), m] }.to_h

no_match = []
familiares_creados = 0
fechas_no_parseadas = []
aliases_registrados = []
matches_fuzzy = []

UMBRAL_MATCH = 0.60  # mínimo para aceptar un match fuzzy
UMBRAL_ALIAS = 0.95  # por encima de esto no registra alias (nombre esencialmente igual)

csv.each do |row|
  nombre_row = row["Nombres y Apellidos "] || row["Nombres y Apellidos"]
  next if nombre_row.blank?
  nombre_row = nombre_row.strip
  norm = normalize(nombre_row)

  # Calcula la mejor coincidencia (fuzzy score sobre todos)
  miembro, score = mejor_coincidencia(norm, mapa_miembros)

  if miembro.nil? || score < UMBRAL_MATCH
    no_match << { nombre: nombre_row, mejor: miembro&.user&.nombre_completo, score: score }
    next
  end

  # Si el match NO fue exacto ni casi-exacto → registra el nombre del CSV como alias
  if score < UMBRAL_ALIAS
    nombre_norm_miembro = normalize(miembro.user.nombre_completo)
    aliases_existentes_norm = miembro.aliases.map { |a| normalize(a) }
    unless aliases_existentes_norm.include?(norm) || norm == nombre_norm_miembro
      miembro.agregar_alias(nombre_row)
      aliases_registrados << "[#{(score*100).round}%] #{miembro.user.nombre_completo}  ←  #{nombre_row}"
    end
    matches_fuzzy << "[#{(score*100).round}%] #{miembro.user.nombre_completo}  ←  #{nombre_row}"
  end

  # ── Esposa / Cuñada ─────────────────────────────────────
  nombre_cun = row["Nombre completo de nuestra Q.·. Cuñ.·."]
  fecha_cun  = row["Fecha de cumpleaños de nuestra Q.·. Cuñ.·."]
  if nombre_cun.present?
    fecha = parse_fecha(fecha_cun)
    fechas_no_parseadas << "esposa de #{miembro.user.nombre_completo}: #{fecha_cun.inspect}" if fecha_cun.present? && fecha.nil?
    f = miembro.familiares.find_or_initialize_by(nombre_completo: nombre_cun.strip)
    f.parentesco      ||= "Esposa"
    f.fecha_nacimiento  = fecha if fecha && f.fecha_nacimiento.nil?
    if f.save
      familiares_creados += 1 if f.previously_new_record?
    end
  end

  # ── Hijos 1..4 ──────────────────────────────────────────
  (1..4).each do |i|
    nombre_h = row["Nombre completo Hij@ #{i}"]
    fecha_h  = row["Fecha de Nacimiento Hij@ #{i}"]
    next if nombre_h.blank?
    fecha = parse_fecha(fecha_h)
    fechas_no_parseadas << "hijo #{i} de #{miembro.user.nombre_completo}: #{fecha_h.inspect}" if fecha_h.present? && fecha.nil?
    parentesco = infer_parentesco_hijo(nombre_h)
    f = miembro.familiares.find_or_initialize_by(nombre_completo: nombre_h.strip)
    f.parentesco      ||= parentesco
    f.fecha_nacimiento  = fecha if fecha && f.fecha_nacimiento.nil?
    if f.save
      familiares_creados += 1 if f.previously_new_record?
    end
  end
end

puts "\n── Resumen ──────────────────────────────"
puts "Familiares creados: #{familiares_creados}"
puts "\nMatches fuzzy (#{matches_fuzzy.size}):"
matches_fuzzy.each { |m| puts "  #{m}" }
puts "\nAliases registrados (#{aliases_registrados.size}):"
aliases_registrados.each { |a| puts "  #{a}" }
puts "\nSin match (#{no_match.size}) — debajo del umbral #{UMBRAL_MATCH}:"
no_match.each do |n|
  mejor_info = n[:mejor] ? " (mejor candidato: #{n[:mejor]} #{(n[:score]*100).round}%)" : ""
  puts "  - #{n[:nombre]}#{mejor_info}"
end
puts "\nFechas no parseadas (#{fechas_no_parseadas.size}):"
fechas_no_parseadas.first(15).each { |f| puts "  - #{f}" }
puts "  (#{fechas_no_parseadas.size - 15} más)" if fechas_no_parseadas.size > 15
puts "\nTotal familiares en el tenant: #{MiembroFamiliar.joins(:miembro).where(miembros: { logia_id: TENANT_LOGIA_IDS }).count}"
puts "Con fecha_nacimiento: #{MiembroFamiliar.joins(:miembro).where(miembros: { logia_id: TENANT_LOGIA_IDS }).where.not(fecha_nacimiento: nil).count}"
