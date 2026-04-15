class SoporteParser
  BANCOS = {
    "Bancolombia" => %w[bancolombia bcolombia],
    "Davivienda" => %w[davivienda],
    "BBVA" => %w[bbva],
    "Banco de Bogotá" => ["banco de bogota", "banco de bogotá", "bbogota"],
    "Nequi" => %w[nequi],
    "Daviplata" => %w[daviplata],
    "Banco Popular" => ["banco popular"],
    "Banco de Occidente" => ["banco de occidente", "occidente"],
    "Scotiabank Colpatria" => ["scotiabank", "colpatria"],
    "AV Villas" => ["av villas", "avvillas"],
    "Banco Caja Social" => ["caja social", "banco caja social"],
    "Itaú" => %w[itau itaú],
    "Banco Falabella" => ["banco falabella", "falabella"],
    "Banco Pichincha" => ["banco pichincha", "pichincha"],
    "GNB Sudameris" => ["gnb sudameris", "gnb"],
    "Banco Agrario" => ["banco agrario", "agrario"],
    "Bancoomeva" => %w[bancoomeva coomeva],
    "Banco W" => ["banco w"],
    "Banco Serfinanza" => %w[serfinanza],
    "Lulo Bank" => ["lulo bank", "lulo"],
    "Nu Colombia" => ["nu colombia", "nubank", "nu bank"],
    "Rappipay" => %w[rappipay rappi],
    "Dale!" => %w[dale],
    "Bold" => %w[bold],
    "Wompi" => %w[wompi],
    "PayU" => %w[payu],
    "MercadoPago" => %w[mercadopago mercadolibre],
    "ePayco" => %w[epayco]
  }.freeze

  MESES = {
    "enero" => 1, "febrero" => 2, "marzo" => 3, "abril" => 4,
    "mayo" => 5, "junio" => 6, "julio" => 7, "agosto" => 8,
    "septiembre" => 9, "octubre" => 10, "noviembre" => 11, "diciembre" => 12,
    "ene" => 1, "feb" => 2, "mar" => 3, "abr" => 4,
    "may" => 5, "jun" => 6, "jul" => 7, "ago" => 8,
    "sep" => 9, "oct" => 10, "nov" => 11, "dic" => 12
  }.freeze

  METODOS_MAP = [
    [/tarjeta(?:s)?(?:\s+(?:de\s+)?cr[eé]dito)?/i, "tarjeta"],
    [/tarjeta(?:s)?(?:\s+(?:de\s+)?d[eé]bito)/i, "tarjeta"],
    [/transferencia/i, "transferencia"],
    [/\bPSE\b/i, "transferencia"],
    [/transfiya/i, "transferencia"],
    [/consignaci[oó]n/i, "consignacion"],
    [/dep[oó]sito/i, "consignacion"],
    [/\bnequi\b/i, "nequi"],
    [/\bdaviplata\b/i, "daviplata"],
    [/efectivo/i, "efectivo"],
    [/\brappipay\b/i, "nequi"],
    [/pago\s+(?:con\s+)?(?:tarjeta|card)/i, "tarjeta"],
    [/\b(?:visa|mastercard|amex|american\s*express|diners)\b/i, "tarjeta"]
  ].freeze

  def initialize(archivo)
    @archivo = archivo
    @temp_files = []
  end

  def call
    texto = extraer_texto_completo
    resultado = analizar_texto(texto)
    resultado[:texto_ocr] = texto.truncate(1000)
    resultado
  ensure
    limpiar_temporales
  end

  private

  # ── Extracción de texto ──

  def extraer_texto_completo
    ext = File.extname(@archivo.original_filename).downcase

    if ext == ".pdf"
      texto = extraer_texto_pdf_nativo
      return texto if texto.present? && texto.strip.length > 30
      Rails.logger.info("SoporteParser: PDF sin texto nativo, usando OCR")
    end

    imagen_path = preparar_imagen
    textos = ejecutar_ocr_multiples(imagen_path)
    elegir_mejor_texto(textos)
  end

  def extraer_texto_pdf_nativo
    reader = PDF::Reader.new(@archivo.tempfile.path)
    texto = reader.pages.map(&:text).join("\n")
    Rails.logger.info("SoporteParser: PDF nativo extrajo #{texto.length} caracteres")
    texto
  rescue => e
    Rails.logger.warn("SoporteParser: error leyendo PDF nativo: #{e.message}")
    ""
  end

  def preparar_imagen
    ext = File.extname(@archivo.original_filename).downcase
    if ext == ".pdf"
      convertir_pdf_a_imagen
    else
      preprocesar_imagen(@archivo.tempfile.path)
    end
  end

  def convertir_pdf_a_imagen
    temp = Tempfile.new(["soporte_pdf", ".png"])
    @temp_files << temp
    img = MiniMagick::Image.open(@archivo.tempfile.path)
    img.combine_options do |c|
      c.density "300"
      c.quality "100"
    end
    img.format("png")
    img.flatten
    img.write(temp.path)
    preprocesar_imagen(temp.path)
  rescue => e
    Rails.logger.warn("SoporteParser: error convirtiendo PDF: #{e.message}")
    preprocesar_imagen(@archivo.tempfile.path)
  end

  def preprocesar_imagen(path)
    temp = Tempfile.new(["soporte_main", ".png"])
    @temp_files << temp
    img = MiniMagick::Image.open(path)
    img.combine_options do |c|
      c.density "300"
      c.colorspace "Gray"
      c.normalize
      c.sharpen "0x2"
      c.threshold "60%"
      c.despeckle
    end
    img.write(temp.path)
    temp.path
  rescue => e
    Rails.logger.warn("SoporteParser: error preprocesando imagen: #{e.message}")
    path
  end

  def preprocesar_imagen_alternativa(path)
    temp = Tempfile.new(["soporte_alt", ".png"])
    @temp_files << temp
    img = MiniMagick::Image.open(path)
    img.combine_options do |c|
      c.density "300"
      c.colorspace "Gray"
      c.normalize
      c.sharpen "0x1"
      c.level "25%,75%"
    end
    img.write(temp.path)
    temp.path
  rescue
    nil
  end

  def ejecutar_ocr_multiples(imagen_path)
    lang = tesseract_lang_disponible?("spa") ? "spa" : "eng"
    textos = []
    textos << ejecutar_ocr_single(imagen_path, lang)
    source = @archivo.tempfile.path
    ext = File.extname(@archivo.original_filename).downcase
    source = imagen_path if ext == ".pdf"
    alt_path = preprocesar_imagen_alternativa(source)
    textos << ejecutar_ocr_single(alt_path, lang) if alt_path
    textos.compact
  end

  def ejecutar_ocr_single(imagen_path, lang)
    rtesseract = RTesseract.new(imagen_path, lang: lang)
    rtesseract.to_s
  rescue => e
    Rails.logger.warn("SoporteParser: error OCR: #{e.message}")
    nil
  end

  def elegir_mejor_texto(textos)
    return "" if textos.empty?
    textos.max_by do |texto|
      score = 0
      score += 3 if texto.match?(/[\d]{1,3}(?:[.,]\d{3})+/)
      score += 2 if texto.match?(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}/)
      score += 1 if BANCOS.values.flatten.any? { |v| texto.downcase.include?(v) }
      score += texto.length / 100.0
      score
    end
  end

  def tesseract_lang_disponible?(lang)
    output = `tesseract --list-langs 2>&1`
    output.include?(lang)
  rescue
    false
  end

  # ── Análisis principal ──

  def analizar_texto(texto)
    lineas = texto.split("\n").map(&:strip).reject(&:blank?)

    {
      monto: extraer_monto(texto),
      fecha: extraer_fecha(texto),
      banco: extraer_banco(texto),
      pagador: extraer_pagador(lineas),
      telefono: extraer_telefono(texto),
      email: extraer_email(texto),
      metodo_pago: extraer_metodo(texto),
      referencia: extraer_referencia(lineas, texto),
      transaccion: extraer_transaccion(lineas, texto),
      detalle_pago: extraer_detalle(lineas),
      destinatario: extraer_destinatario(lineas, texto),
      estado: extraer_estado(texto),
      cuenta_destino: extraer_cuenta_destino(lineas),
      confianza: nil # se calcula después
    }.tap { |r| r[:confianza] = calcular_confianza(r, texto) }
  end

  # ── Monto ──

  def extraer_monto(texto)
    candidatos = []

    # COP o $ seguido de monto
    texto.scan(/(?:COP|\$)\s*([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)/) do |match|
      monto = normalizar_monto(match[0])
      candidatos << { valor: monto, prioridad: 3 } if monto
    end

    # Monto seguido de COP
    texto.scan(/([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)\s*COP/i) do |match|
      monto = normalizar_monto(match[0])
      candidatos << { valor: monto, prioridad: 3 } if monto
    end

    # Labels explícitos
    texto.scan(/(?:valor|monto|total|vlr|importe|valor\s+pagado|valor\s+total|total\s+pagado)\s*[:\-]?\s*\$?\s*([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)/i) do |match|
      monto = normalizar_monto(match[0])
      candidatos << { valor: monto, prioridad: 2 } if monto
    end

    # Formato colombiano suelto
    texto.scan(/([\d]{1,3}(?:\.\d{3})+(?:,\d{1,2})?)/) do |match|
      monto = normalizar_monto(match[0])
      candidatos << { valor: monto, prioridad: 1 } if monto
    end

    return nil if candidatos.empty?
    candidatos.sort_by { |c| [-c[:prioridad], -c[:valor]] }.first[:valor]
  end

  def normalizar_monto(raw)
    return nil if raw.blank?
    limpio = raw.gsub(/\.(?=\d{3})/, "").gsub(",", ".")
    valor = limpio.to_f.round(0).to_i
    valor.between?(1_000, 50_000_000) ? valor : nil
  rescue
    nil
  end

  # ── Fecha ──

  def extraer_fecha(texto)
    candidatos = []

    texto.scan(/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/) do |dia, mes, anio|
      candidatos << formatear_fecha(anio.to_i, mes.to_i, dia.to_i)
    end

    texto.scan(/(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})/) do |anio, mes, dia|
      candidatos << formatear_fecha(anio.to_i, mes.to_i, dia.to_i)
    end

    texto.scan(/(\d{1,2})\s+de\s+(\w+)\s+(?:de\s+|del\s+)?(\d{4})/i) do |dia, mes_nombre, anio|
      mes = MESES[mes_nombre.downcase]
      candidatos << formatear_fecha(anio.to_i, mes, dia.to_i) if mes
    end

    texto.scan(/(\w+)\s+(\d{1,2}),?\s+(?:de\s+)?(\d{4})/i) do |mes_nombre, dia, anio|
      mes = MESES[mes_nombre.downcase]
      candidatos << formatear_fecha(anio.to_i, mes, dia.to_i) if mes
    end

    texto.scan(/(\d{1,2})[\/\-](\w{3,4})[\/\-](\d{4})/i) do |dia, mes_nombre, anio|
      mes = MESES[mes_nombre.downcase]
      candidatos << formatear_fecha(anio.to_i, mes, dia.to_i) if mes
    end

    candidatos.compact.max
  end

  def formatear_fecha(anio, mes, dia)
    return nil unless mes&.between?(1, 12) && dia.between?(1, 31) && anio.between?(2020, 2100)
    Date.new(anio, mes, dia).iso8601
  rescue ArgumentError
    nil
  end

  # ── Banco ──

  def extraer_banco(texto)
    texto_lower = texto.downcase
    BANCOS.sort_by { |_, variantes| -variantes.map(&:length).max }.each do |nombre, variantes|
      return nombre if variantes.any? { |v| texto_lower.include?(v) }
    end
    nil
  end

  # ── Pagador (nombre) ──

  def extraer_pagador(lineas)
    # Buscar label "Nombre" seguido del valor
    lineas.each_with_index do |linea, i|
      # "Nombre   CARLOS ENRIQUE MORALES" en la misma línea
      if linea.match?(/\A\s*nombre\s/i)
        valor = linea.sub(/\A\s*nombre\s*/i, "").strip
        return limpiar_nombre(valor) if nombre_valido?(valor)
        # Siguiente línea
        sig = lineas[i + 1]
        return limpiar_nombre(sig) if sig && nombre_valido?(sig)
      end
    end

    # Labels más amplios
    labels = /(?:pagador|ordenante|titular|nombre\s+del\s+(?:cliente|pagador|ordenante)|cliente|enviado\s+por|remitente|de:)\s*[:\-]?\s*/i
    lineas.each_with_index do |linea, i|
      next unless linea.match?(labels)
      valor = linea.sub(labels, "").strip
      return limpiar_nombre(valor) if nombre_valido?(valor)
      sig = lineas[i + 1]
      return limpiar_nombre(sig) if sig && nombre_valido?(sig)
    end

    # Buscar en sección "Información del pagador"
    en_seccion_pagador = false
    lineas.each do |linea|
      if linea.match?(/informaci[oó]n\s+del\s+pagador/i)
        en_seccion_pagador = true
        next
      end

      if en_seccion_pagador
        # Primera línea con texto tipo nombre (solo letras y espacios)
        limpio = linea.sub(/\A\s*nombre\s*/i, "").strip
        if nombre_valido?(limpio)
          return limpiar_nombre(limpio)
        end
        # Si pasamos 3 líneas sin encontrar nombre, parar
        en_seccion_pagador = false if linea.match?(/tel[eé]fono|email|referencia|pago/i)
      end
    end

    nil
  end

  # ── Teléfono ──

  def extraer_telefono(texto)
    # +573133779202 o 3133779202 o 313 377 9202
    if texto.match?(/(?:tel[eé]fono|celular|m[oó]vil|tel\.?)\s*[:\-]?\s*/i)
      match = texto.match(/(?:tel[eé]fono|celular|m[oó]vil|tel\.?)\s*[:\-]?\s*(\+?\d[\d\s\-]{7,15})/i)
      return match[1].gsub(/\s+/, "") if match
    end

    # Número colombiano suelto
    match = texto.match(/(\+57\d{10}|\+57\s?\d{3}\s?\d{3}\s?\d{4})/)
    return match[1].gsub(/\s+/, "") if match

    nil
  end

  # ── Email ──

  def extraer_email(texto)
    # Con label
    match = texto.match(/(?:email|correo|e-?mail)\s*[:\-]?\s*([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})/i)
    return match[1] if match

    # Sin label
    match = texto.match(/([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})/)
    return match[1] if match

    nil
  end

  # ── Método de pago ──

  def extraer_metodo(texto)
    METODOS_MAP.each do |patron, metodo|
      return metodo if texto.match?(patron)
    end

    # Inferir de banco
    banco = extraer_banco(texto)
    case banco
    when "Nequi" then "nequi"
    when "Daviplata" then "daviplata"
    else nil
    end
  end

  # ── Referencia ──

  def extraer_referencia(lineas, texto)
    # "Referencia Yq5f1n_1773081196895_vkzikvzpger"
    lineas.each do |linea|
      if linea.match?(/\A\s*referencia\s/i)
        valor = linea.sub(/\A\s*referencia\s*/i, "").strip
        return valor if valor.present? && valor.length >= 4 && valor.length <= 60
      end
    end

    # Label + valor
    match = texto.match(/(?:referencia|ref\.?|c[oó]digo\s+[uú]nico|CUS)\s*[:\-#]?\s*([\w\-\.]{4,60})/i)
    return match[1] if match

    nil
  end

  # ── Número de transacción ──

  def extraer_transaccion(lineas, texto)
    # "Transacción # 1143038-1773081749-67416"
    lineas.each do |linea|
      match = linea.match(/transacci[oó]n\s*#?\s*([\d\-]{4,40})/i)
      return match[1] if match
    end

    # Otros patrones
    match = texto.match(/(?:no\.?\s*(?:de\s+)?transacci[oó]n|id\s+transacci[oó]n|n[uú]mero\s+(?:de\s+)?(?:transacci[oó]n|aprobaci[oó]n|operaci[oó]n|comprobante))\s*[:\-#]?\s*([\w\-]{4,40})/i)
    return match[1] if match

    nil
  end

  # ── Detalle del pago ──

  def extraer_detalle(lineas)
    # Buscar sección "Referencias del pago" / "DETALLE DEL PAGO" / "Descripción" / "Concepto"
    en_seccion = false
    detalle_lineas = []

    lineas.each do |linea|
      if linea.match?(/(?:referencias?\s+del\s+pago|detalle\s+del\s+pago|descripci[oó]n|concepto\s+del?\s+pago)/i)
        en_seccion = true
        # Si hay texto después del label en la misma línea
        valor = linea.sub(/.*(?:referencias?\s+del\s+pago|detalle\s+del\s+pago|descripci[oó]n|concepto\s+del?\s+pago)\s*/i, "").strip
        detalle_lineas << valor if valor.present?
        next
      end

      if en_seccion
        # Parar si encontramos otra sección
        if linea.match?(/\A\s*(?:nombre\s+del|informaci[oó]n|estado|fecha|total|monto|pagador|tel[eé]fono|email)\s/i)
          en_seccion = false
          next
        end
        detalle_lineas << linea if linea.present? && linea.length > 2
      end
    end

    detalle = detalle_lineas.join(" ").strip
    detalle.present? ? detalle.truncate(200) : nil
  end

  # ── Destinatario (a quién se paga) ──

  def extraer_destinatario(lineas, texto)
    # "Pago a\n\nGRAN LOGIA DE COLOMBIA"
    lineas.each_with_index do |linea, i|
      if linea.match?(/\A\s*pago\s+a\s*\z/i)
        sig = lineas[i + 1]
        return sig.strip if sig && sig.strip.length > 2
      end
    end

    # "Beneficiario: ..."
    match = texto.match(/(?:beneficiario|destino|pago\s+a)\s*[:\-]?\s*(.{3,60})/i)
    return match[1].strip if match

    nil
  end

  # ── Estado de la transacción ──

  def extraer_estado(texto)
    return "aprobada" if texto.match?(/transacci[oó]n\s+aprobada|pago\s+(?:exitoso|aprobado|confirmado)|aprobad[oa]/i)
    return "pendiente" if texto.match?(/pendiente|en\s+proceso/i)
    return "rechazada" if texto.match?(/rechazad[oa]|declinad[oa]|fallid[oa]|no\s+aprobad[oa]/i)
    nil
  end

  # ── Cuenta destino ──

  def extraer_cuenta_destino(lineas)
    lineas.each do |linea|
      next unless linea.match?(/(?:cuenta\s+(?:de\s+)?destino|cuenta\s+beneficiario|n[uú]mero\s+de\s+cuenta|cuenta\s*(?:no\.?)?|cuenta\s+cr[eé]dito)\s*[:\-]?\s*/i)
      match = linea.match(/(\d{9,16})/)
      return match[1] if match
    end
    nil
  end

  # ── Nombre del taller/logia (del pago) ──

  def extraer_nombre_taller(lineas)
    lineas.each_with_index do |linea, i|
      if linea.match?(/nombre\s+del\s+taller/i)
        valor = linea.sub(/.*nombre\s+del\s+taller\s*/i, "").strip
        return valor if valor.present? && valor.length > 2
        sig = lineas[i + 1]
        return sig.strip if sig && sig.strip.length > 2
      end
    end
    nil
  end

  # ── Confianza ──

  def calcular_confianza(resultado, texto)
    score = 0
    score += 2 if resultado[:monto].present?
    score += 1 if resultado[:fecha].present?
    score += 1 if resultado[:banco].present?
    score += 1 if resultado[:metodo_pago].present?
    score += 2 if resultado[:pagador].present?
    score += 1 if resultado[:referencia].present? || resultado[:transaccion].present?
    score += 1 if resultado[:estado] == "aprobada"
    score += 1 if texto.length > 200

    case score
    when 0..2 then "baja"
    when 3..5 then "media"
    else "alta"
    end
  end

  # ── Helpers ──

  def nombre_valido?(texto)
    return false if texto.blank? || texto.length < 3
    texto.match?(/[a-zA-ZáéíóúÁÉÍÓÚñÑ]{2,}/) &&
      !texto.match?(/\A[\d\s\$\.,]+\z/) &&
      !texto.match?(/transacci[oó]n|referencia|email|tel[eé]fono|informaci[oó]n|pago/i) &&
      texto.length < 80
  end

  def limpiar_nombre(nombre)
    limpio = nombre.gsub(/\s*[\d\*]{4,}.*\z/, "")
                   .gsub(/[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s\.\-]/, "")
                   .strip
                   .squeeze(" ")
    limpio.present? ? limpio.titleize : nil
  end

  def limpiar_temporales
    @temp_files.each do |f|
      f.close rescue nil
      f.unlink rescue nil
    end
  end
end
