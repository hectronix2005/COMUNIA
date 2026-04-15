# frozen_string_literal: true

require "csv"

# Parses an uploaded file and reconciles members against the system.
# Supports: CSV, Excel (xlsx/xls via roo), PDF (pdf-reader)
#
# Gran Logia Excel format (reporte de terceros):
#   Col T (20): NOMBRE  (etiqueta en U/21, dato en T/20)
#   Col AH(34): NIT/CEDULA
#   Cell V7 (row=7, col=22): fecha del corte
class CorteConciliacionParser

  # Columnas fijas del reporte Gran Logia (1-based para roo)
  COL_NOMBRE    = 20  # T
  COL_CEDULA    = 34  # AH
  FECHA_ROW     = 7
  FECHA_COL     = 22  # V
  DATOS_DESDE   = 14  # filas de datos empiezan después del encabezado

  def initialize(corte)
    @corte = corte
    @palabras_cache = {}
  end

  # Extrae solo la fecha del archivo (usado antes de guardar el corte)
  def self.extraer_fecha(uploaded_file)
    return nil unless uploaded_file.present?

    ext = File.extname(uploaded_file.original_filename.to_s).downcase.delete(".").presence || "xlsx"
    return nil unless %w[xlsx xls].include?(ext)

    require "roo"
    Tempfile.create(["corte_fecha", ".#{ext}"]) do |tmp|
      tmp.binmode
      tmp.write(uploaded_file.read)
      uploaded_file.rewind
      tmp.rewind
      sheet = Roo::Spreadsheet.open(tmp.path, extension: ext.to_sym).sheet(0)
      cell  = sheet.cell(FECHA_ROW, FECHA_COL)
      parse_fecha_celda(cell)
    end
  rescue StandardError => e
    Rails.logger.warn("CorteConciliacionParser.extraer_fecha: #{e.class} #{e.message}")
    nil
  end

  # Procesa el archivo y reconcilia. No re-lanza excepciones — guarda estado :error_parser.
  def procesar!
    entradas = extraer_entradas
    reconciliar(entradas)
  rescue StandardError => e
    Rails.logger.error(
      "CorteConciliacionParser error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    )
    @corte.update_columns(
      estado:    CorteConciliacion.estados[:error_parser],
      resultado: { "error" => e.message, "coincidentes" => [], "sin_match" => [],
                   "solo_en_sistema" => [], "inactivos_en_archivo" => [], "no_aplica" => [] }
    )
  end

  private

  # ── Detección de formato ──────────────────────────────────────────────────────

  def extraer_entradas
    content_type = @corte.archivo.content_type.to_s
    formato      = detectar_formato(content_type)
    @corte.update_column(:formato_archivo, formato)

    case formato
    when "excel" then parsear_excel_gran_logia
    when "csv"   then parsear_csv(descargar_texto)
    when "pdf"   then parsear_pdf
    else              parsear_csv(descargar_texto)
    end
  end

  def detectar_formato(content_type)
    return "pdf"   if content_type.include?("pdf")
    return "excel" if content_type.include?("spreadsheet") || content_type.include?("excel") ||
                      content_type.include?("xlsx") || content_type.include?("xls")
    "csv"
  end

  def descargar_texto
    raw = @corte.archivo.download
    raw.force_encoding("UTF-8").valid_encoding? ? raw : raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  # ── Excel Gran Logia ─────────────────────────────────────────────────────────
  # Columnas fijas: T(20)=NOMBRE, AH(34)=CEDULA, fecha en V7
  def parsear_excel_gran_logia
    require "roo"
    ext = File.extname(@corte.archivo.filename.to_s).downcase.delete(".").presence || "xlsx"

    Tempfile.create(["corte", ".#{ext}"]) do |tmp|
      tmp.binmode
      tmp.write(@corte.archivo.download)
      tmp.rewind

      sheet = Roo::Spreadsheet.open(tmp.path, extension: ext.to_sym).sheet(0)

      # Guardia: archivo demasiado corto
      return [] if sheet.last_row.nil? || sheet.last_row < DATOS_DESDE

      # Actualizar fecha del corte si no fue indicada manualmente
      fecha = parse_fecha_celda(sheet.cell(FECHA_ROW, FECHA_COL))
      @corte.update_column(:fecha_corte, fecha) if fecha && @corte.fecha_corte != fecha

      entradas = []
      (DATOS_DESDE..sheet.last_row).each do |r|
        nombre = sheet.cell(r, COL_NOMBRE).to_s.strip
        cedula = limpiar_numero(sheet.cell(r, COL_CEDULA).to_s)
        next if nombre.blank? && cedula.blank?

        entradas << { nombre: nombre.presence, cedula: cedula.presence }
      end
      entradas
    end
  rescue LoadError
    Rails.logger.warn("roo no disponible, intentando como CSV")
    parsear_csv(descargar_texto)
  end

  # ── CSV ──────────────────────────────────────────────────────────────────────
  def parsear_csv(texto)
    entradas = []
    begin
      csv            = CSV.parse(texto.strip, headers: true, encoding: "UTF-8", liberal_parsing: true)
      headers_lower  = csv.headers.map { |h| h.to_s.downcase.strip }

      idx_cedula = detectar_col(headers_lower, %w[cedula cc documento identificacion id nit])
      idx_numero = detectar_col(headers_lower, %w[numero no. no # numero_miembro num membresia])
      idx_nombre = detectar_col(headers_lower, %w[nombre name apellido apellidos nombres completo])

      csv.each do |row|
        e = {
          cedula: idx_cedula ? limpiar_numero(row[csv.headers[idx_cedula]])  : nil,
          numero: idx_numero ? row[csv.headers[idx_numero]]&.strip           : nil,
          nombre: idx_nombre ? row[csv.headers[idx_nombre]]&.strip           : nil
        }
        entradas << e if valida?(e)
      end
    rescue CSV::MalformedCSVError
      CSV.parse(texto.strip, headers: false).each_with_index do |row, i|
        next if i.zero?
        e = { cedula: limpiar_numero(row[0]), nombre: row[1]&.strip }
        entradas << e if valida?(e)
      end
    end
    entradas
  end

  # ── PDF ──────────────────────────────────────────────────────────────────────
  def parsear_pdf
    texto = ""
    begin
      require "pdf-reader"
      reader = PDF::Reader.new(StringIO.new(@corte.archivo.download))
      texto  = reader.pages.map(&:text).join("\n")
    rescue StandardError => e
      Rails.logger.warn("PDF::Reader error: #{e.message}")
    end

    # Solo cédulas con longitud válida para Colombia (6-10 dígitos)
    cedulas = texto.scan(/(?<!\d)(\d{6,10})(?!\d)/).flatten.uniq
    nombres = texto.scan(/\b([A-ZÁÉÍÓÚÑ]{2,}(?:\s+[A-ZÁÉÍÓÚÑ]{2,}){1,5})\b/)
                   .flatten.uniq
                   .select { |n| n.split.length >= 2 }

    entradas = []
    [cedulas.size, nombres.size].max.times do |i|
      e = { cedula: cedulas[i], nombre: nombres[i] }
      entradas << e if valida?(e)
    end
    entradas = nombres.map { |n| { nombre: n } } if entradas.empty? && nombres.any?
    entradas
  end

  # ── Reconciliación ───────────────────────────────────────────────────────────
  def reconciliar(entradas)
    fecha    = @corte.fecha_corte
    logia_id = @corte.logia_id

    # Carga todos los miembros de la logia una sola vez, luego filtra activos por IDs
    todos       = Miembro.where(logia_id: logia_id).includes(:user).to_a
    ids_activos = Miembro.en_estado_en_fecha("activo", fecha)
                         .where(logia_id: logia_id)
                         .pluck(:id)
                         .to_set

    activos          = todos.select { |m| ids_activos.include?(m.id) }
    todos_por_cedula = todos.index_by { |m| limpiar_numero(m.cedula) }
    no_aplica        = todos.reject { |m| ids_activos.include?(m.id) }.map { |m| serial(m) }

    # Índices de búsqueda sobre activos
    por_cedula = activos.index_by { |m| limpiar_numero(m.cedula) }
    por_numero = activos.index_by(&:numero_miembro)

    # Índice invertido por palabra: nombre completo + aliases conocidos
    word_index = Hash.new { |h, k| h[k] = [] }
    activos.each do |m|
      palabras(m.nombre_completo).each { |w| word_index[w] << m }
      m.aliases.each { |a| palabras(a).each { |w| word_index[w] |= [m] } }
    end

    coincidentes         = []
    sin_match            = []   # en archivo, no existe en ningún estado en sistema
    inactivos_en_archivo = []   # en archivo, existe en sistema pero no activo a la fecha
    ids_encontrados      = Set.new

    entradas.each do |e|
      m  = por_cedula[e[:cedula]] if e[:cedula].present?
      m ||= por_numero[e[:numero]] if e[:numero].present?
      m ||= buscar_por_nombre(e[:nombre], word_index) if e[:nombre].present?

      if m
        score = coincidencia_score(e, m)
        m.agregar_alias(e[:nombre]) if e[:nombre].present?
        coincidentes    << serial(m).merge("score" => score, "nombre_archivo" => e[:nombre])
        ids_encontrados << m.id
      else
        otro = e[:cedula].present? ? todos_por_cedula[e[:cedula]] : nil
        if otro
          inactivos_en_archivo << e.transform_keys(&:to_s).merge(
            "miembro_id"    => otro.id,
            "nombre_sistema" => otro.nombre_completo,
            "estado_sistema" => otro.estado
          )
        else
          sin_match << e.transform_keys(&:to_s).merge("diagnostico" => "No encontrado en el sistema")
        end
      end
    end

    # solo_en_sistema: activos a la fecha que no aparecen en el archivo
    solo_en_sistema = activos.reject { |m| ids_encontrados.include?(m.id) }
                             .map { |m| serial(m).merge("estado" => "activo") }

    estado = (sin_match.any? || solo_en_sistema.any?) ? :con_diferencias : :procesado

    @corte.update!(
      resultado:     {
        "coincidentes"         => coincidentes,
        "sin_match"            => sin_match,
        "inactivos_en_archivo" => inactivos_en_archivo,
        "solo_en_sistema"      => solo_en_sistema,
        "no_aplica"            => no_aplica
      },
      estado:        estado,
      total_archivo: entradas.size,
      total_sistema: activos.size
    )
  end

  # ── Matching por nombre ───────────────────────────────────────────────────────
  # "ABUASSI ESPITIA RICARDO" ↔ "Ricardo Abuassi" → 2 palabras comunes → match
  def buscar_por_nombre(nombre, word_index)
    return nil if nombre.blank?

    palabras_archivo = palabras(nombre)
    return nil if palabras_archivo.empty?

    scores = Hash.new(0)
    palabras_archivo.each { |w| word_index[w]&.each { |m| scores[m] += 1 } }
    return nil if scores.empty?

    mejor, count = scores.max_by { |_, v| v }
    palabras_db  = palabras(mejor.nombre_completo)

    # Umbral: al menos 2 palabras en común
    min_requerido = [2, [palabras_archivo.size, palabras_db.size].min].min
    count >= min_requerido ? mejor : nil
  end

  def coincidencia_score(entrada, miembro)
    return 100 if limpiar_numero(entrada[:cedula]) == limpiar_numero(miembro.cedula)

    palabras_a = palabras(entrada[:nombre].to_s)
    palabras_b = palabras(miembro.nombre_completo)
    return 0 if palabras_a.empty? || palabras_b.empty?

    shared = (palabras_a & palabras_b).size
    ((shared.to_f / [palabras_a.size, palabras_b.size].max) * 100).round
  end

  def serial(m)
    { "miembro_id" => m.id, "nombre" => m.nombre_completo,
      "cedula" => m.cedula, "numero" => m.numero_miembro,
      "estado" => m.estado }
  end

  # Normaliza a palabras ASCII minúsculas sin duplicados. Memoizado por instancia.
  def palabras(str)
    return [] if str.blank?

    @palabras_cache[str] ||= begin
      n = str.downcase.strip
      n = n.tr("áéíóúñüÁÉÍÓÚÑÜ", "aeiounuAEIOUNU")
      n.gsub(/[^a-z\s]/, "").split.uniq
    end
  end

  # Fecha desde celda Excel: acepta Date nativo o strings con formato yyyy-mm-dd / dd/mm/yyyy
  def self.parse_fecha_celda(cell)
    return nil if cell.blank?
    return cell if cell.is_a?(Date)

    str = cell.to_s.strip
    if str =~ /\A(\d{4})-(\d{2})-(\d{2})\z/
      Date.new($1.to_i, $2.to_i, $3.to_i)
    elsif str =~ %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\z}
      Date.new($3.to_i, $2.to_i, $1.to_i)
    else
      Date.parse(str)
    end
  rescue ArgumentError, TypeError
    nil
  end

  def parse_fecha_celda(cell) = self.class.parse_fecha_celda(cell)

  def detectar_col(headers, candidatos)
    headers.index { |h| candidatos.any? { |c| h.include?(c) } }
  end

  def limpiar_numero(str)
    str.to_s.gsub(/\D/, "").presence
  end

  def valida?(e)
    e[:cedula].present? || e[:numero].present? || e[:nombre].present?
  end
end
