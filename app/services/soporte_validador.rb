class SoporteValidador
  # Valida los datos extraídos del parser contra el cobro/miembro real.
  # Retorna el resultado enriquecido con alertas y confianza ajustada.

  def initialize(datos_ocr, cobro)
    @datos = datos_ocr.deep_symbolize_keys
    @cobro = cobro
    @pago = cobro.pago
    @miembro = cobro.miembro
    @user = @miembro.user
    @alertas = []
  end

  def call
    validar_pagador
    validar_monto
    validar_metodo
    validar_estado

    @datos[:alertas] = @alertas
    @datos[:confianza] = calcular_confianza
    @datos
  end

  private

  # ── Validación de pagador vs miembro ──

  def validar_pagador
    return if @datos[:pagador].blank?

    nombre_miembro = @user.nombre_completo
    nombre_pagador = @datos[:pagador]
    @datos[:nombre_miembro] = nombre_miembro

    similitud = calcular_similitud(nombre_pagador.downcase, nombre_miembro.downcase)
    @datos[:similitud_pagador] = (similitud * 100).round(0)

    if similitud >= 0.7
      @datos[:pagador_match] = true
      @alertas << {
        tipo: "success",
        campo: "pagador",
        mensaje: "El pagador '#{nombre_pagador}' coincide con el miembro '#{nombre_miembro}'."
      }
    elsif coincide_parcial?(nombre_pagador.downcase, nombre_miembro.downcase)
      @datos[:pagador_match] = "parcial"
      @alertas << {
        tipo: "warning",
        campo: "pagador",
        mensaje: "El pagador '#{nombre_pagador}' coincide parcialmente con el miembro '#{nombre_miembro}' (#{@datos[:similitud_pagador]}% similitud). Verifique que sea la misma persona."
      }
    else
      @datos[:pagador_match] = false
      @alertas << {
        tipo: "danger",
        campo: "pagador",
        mensaje: "El pagador '#{nombre_pagador}' NO coincide con el miembro '#{nombre_miembro}' (#{@datos[:similitud_pagador]}% similitud). El pago podría ser de otra persona."
      }
    end
  end

  # ── Validación de monto ──

  def validar_monto
    return if @datos[:monto].blank? || @pago.blank?

    monto_detectado = @datos[:monto].to_i
    monto_cobro = @cobro.monto.to_i
    monto_pagado = @pago.monto_pagado.to_i

    cobros_grupo = @pago.cobros_grupo
    monto_total_grupo = cobros_grupo.sum(:monto).to_i
    num_cobros = cobros_grupo.count

    @datos[:monto_cobro] = monto_cobro
    @datos[:monto_total_grupo] = monto_total_grupo
    @datos[:num_cobros] = num_cobros

    coincide = monto_detectado == monto_total_grupo ||
               monto_detectado == monto_pagado ||
               monto_detectado == monto_cobro

    if coincide
      @datos[:monto_match] = true
      # Siempre mostrar la comparación al admin
      if num_cobros > 1
        @alertas << {
          tipo: "info",
          campo: "monto",
          mensaje: "Monto del soporte ($#{format_cop(monto_detectado)}) corresponde al total de #{num_cobros} cobros (#{num_cobros} × $#{format_cop(monto_cobro)} = $#{format_cop(monto_total_grupo)})."
        }
      else
        @alertas << {
          tipo: "info",
          campo: "monto",
          mensaje: "Monto del soporte ($#{format_cop(monto_detectado)}) coincide con el cobro ($#{format_cop(monto_total_grupo)})."
        }
      end
    else
      @datos[:monto_match] = false
      diferencia = monto_detectado - monto_total_grupo
      porcentaje = monto_total_grupo > 0 ? ((diferencia.abs.to_f / monto_total_grupo) * 100).round(1) : 0

      if num_cobros > 1
        detalle = "Total esperado: #{num_cobros} cobros × $#{format_cop(monto_cobro)} = $#{format_cop(monto_total_grupo)}."
      else
        detalle = "Monto esperado del cobro: $#{format_cop(monto_total_grupo)}."
      end

      if porcentaje <= 5
        @alertas << {
          tipo: "warning",
          campo: "monto",
          mensaje: "El monto del soporte ($#{format_cop(monto_detectado)}) difiere ligeramente del esperado. #{detalle} Diferencia: #{porcentaje}%."
        }
      else
        @alertas << {
          tipo: "danger",
          campo: "monto",
          mensaje: "El monto del soporte ($#{format_cop(monto_detectado)}) NO coincide. #{detalle} Diferencia: $#{format_cop(diferencia.abs)} (#{porcentaje}%)."
        }
      end
    end
  end

  # ── Validación de método de pago ──

  def validar_metodo
    return if @datos[:metodo_pago].blank? || @pago.blank?

    metodo_detectado = @datos[:metodo_pago]
    metodo_declarado = @pago.metodo_pago

    if metodo_detectado == metodo_declarado
      @datos[:metodo_match] = true
    else
      # Algunos son equivalentes
      equivalentes = {
        "tarjeta" => %w[transferencia],
        "transferencia" => %w[tarjeta]
      }
      if equivalentes[metodo_detectado]&.include?(metodo_declarado)
        @datos[:metodo_match] = "parcial"
        @alertas << {
          tipo: "info",
          campo: "metodo",
          mensaje: "El método detectado (#{metodo_detectado}) difiere del declarado (#{metodo_declarado}), pero podrían ser equivalentes."
        }
      else
        @datos[:metodo_match] = false
        @alertas << {
          tipo: "warning",
          campo: "metodo",
          mensaje: "El método detectado (#{metodo_detectado}) no coincide con el declarado (#{metodo_declarado})."
        }
      end
    end
  end

  # ── Validación de estado ──

  def validar_estado
    return if @datos[:estado].blank?

    if @datos[:estado] == "rechazada"
      @alertas << {
        tipo: "danger",
        campo: "estado",
        mensaje: "La transacción aparece como RECHAZADA en el comprobante. No debería aprobarse este pago."
      }
    elsif @datos[:estado] == "pendiente"
      @alertas << {
        tipo: "warning",
        campo: "estado",
        mensaje: "La transacción aparece como PENDIENTE en el comprobante. Espere confirmación antes de aprobar."
      }
    end
  end

  # ── Cálculo de confianza final ──

  def calcular_confianza
    score = 0
    max_score = 0

    # Datos detectados (positivo)
    score += 2 if @datos[:monto].present?
    score += 1 if @datos[:fecha].present?
    score += 1 if @datos[:banco].present? || @datos[:destinatario].present?
    score += 1 if @datos[:metodo_pago].present?
    score += 2 if @datos[:pagador].present?
    score += 1 if @datos[:referencia].present? || @datos[:transaccion].present?
    score += 1 if @datos[:estado] == "aprobada"
    max_score = 9

    # Validaciones cruzadas (pueden restar)
    if @datos[:pagador_match] == true
      score += 3
    elsif @datos[:pagador_match] == "parcial"
      score += 1
    elsif @datos[:pagador_match] == false
      score -= 4  # Penalización fuerte: pagador no coincide
    end
    max_score += 3

    if @datos[:monto_match] == true
      score += 2
    elsif @datos[:monto_match] == false
      score -= 3
    end
    max_score += 2

    if @datos[:metodo_match] == true
      score += 1
    elsif @datos[:metodo_match] == false
      score -= 1
    end
    max_score += 1

    if @datos[:estado] == "rechazada"
      score -= 5
    elsif @datos[:estado] == "pendiente"
      score -= 2
    end

    # Alertas de peligro reducen más
    alertas_danger = @alertas.count { |a| a[:tipo] == "danger" }
    score -= alertas_danger * 2

    # Normalizar
    porcentaje = max_score > 0 ? (score.to_f / max_score * 100).round(0) : 0
    porcentaje = [porcentaje, 0].max

    @datos[:confianza_score] = porcentaje

    if porcentaje >= 75
      "alta"
    elsif porcentaje >= 40
      "media"
    else
      "baja"
    end
  end

  # ── Helpers ──

  def calcular_similitud(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.blank? || str2.blank?

    # Normalizar
    a = normalizar_texto(str1)
    b = normalizar_texto(str2)

    return 1.0 if a == b

    # Palabras en común
    palabras_a = a.split(/\s+/).reject { |p| p.length < 2 }
    palabras_b = b.split(/\s+/).reject { |p| p.length < 2 }

    return 0.0 if palabras_a.empty? || palabras_b.empty?

    comunes = (palabras_a & palabras_b).length
    total = [palabras_a.length, palabras_b.length].max

    comunes.to_f / total
  end

  def coincide_parcial?(nombre_pagador, nombre_miembro)
    palabras_pagador = normalizar_texto(nombre_pagador).split(/\s+/).reject { |p| p.length < 2 }
    palabras_miembro = normalizar_texto(nombre_miembro).split(/\s+/).reject { |p| p.length < 2 }

    return false if palabras_pagador.empty? || palabras_miembro.empty?

    # Al menos un apellido o nombre en común
    comunes = (palabras_pagador & palabras_miembro)
    comunes.any? { |p| p.length >= 3 }
  end

  def normalizar_texto(texto)
    texto.downcase
         .gsub(/[áà]/, "a").gsub(/[éè]/, "e").gsub(/[íì]/, "i")
         .gsub(/[óò]/, "o").gsub(/[úù]/, "u").gsub(/ñ/, "n")
         .gsub(/[^a-z\s]/, "")
         .strip
         .squeeze(" ")
  end

  def format_cop(monto)
    monto.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end
