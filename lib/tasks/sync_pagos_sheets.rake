namespace :sync do
  desc "Sincroniza pagos desde Google Sheets. Uso: rake sync:pagos_sheets"
  task pagos_sheets: :environment do
    require "csv"
    require "open-uri"
    require "bigdecimal"

    SHEET_URL = "https://docs.google.com/spreadsheets/d/1K7EvKf-YNcLy2iJlj3wbVFKLMtmlQFXu/export?format=csv&gid=1689154612".freeze

    # Índices de columnas (0-based)
    COL_NOMBRE    = 45  # AT  – NAME LIST
    COL_ANO       = 46  # AU
    COL_MES       = 47  # AV
    COL_FECHA     = 48  # AW  – fecha consignación
    COL_RC        = 50  # AY  – CONSECUTIVO
    COL_VALOR     = 51  # AZ  – VALOR CONSIGNADO
    COL_NOTA      = 52  # BA

    stats = { importados: 0, importados_sin_rc: 0, omitidos_dup: 0,
              omitidos_sin_miembro: 0, errores: 0, no_coinciden: [] }

    admin = User.joins(:rol_ref).find_by(roles: { codigo: "super_admin" }) ||
            User.joins(:rol_ref).find_by(roles: { codigo: "admin_logia" })

    unless admin
      puts "ERROR: No se encontró usuario admin para atribuir periodos creados."
      exit 1
    end

    puts "Descargando hoja de cálculo..."
    csv_data = URI.open(SHEET_URL).read
    rows = CSV.parse(csv_data, liberal_parsing: true)
    puts "#{rows.size} filas encontradas. Procesando pagos..."

    rows.each_with_index do |row, idx|
      next if idx < 4                           # saltar filas de cabecera
      next if row[COL_NOMBRE].to_s.strip.blank? # fila sin datos de pago

      nombre_hoja = row[COL_NOMBRE].to_s.strip.upcase
      rc_raw      = row[COL_RC].to_s.strip
      valor_raw   = row[COL_VALOR].to_s.strip
      fecha_raw   = row[COL_FECHA].to_s.strip
      ano_raw     = row[COL_ANO].to_s.strip
      mes_raw     = row[COL_MES].to_s.strip
      nota        = row[COL_NOTA].to_s.strip

      # RC Pendiente = pagó pero aún sin número oficial → importar sin numero_rc
      rc_pendiente = rc_raw.blank? || rc_raw.upcase.include?("PENDIENTE")
      rc_numero    = rc_pendiente ? nil : rc_raw.gsub(/\s+/, " ").strip

      # Deduplicar: si tiene RC, verificar que no exista ya
      if rc_numero.present? && Pago.where("LOWER(TRIM(numero_rc)) = ?", rc_numero.downcase).exists?
        stats[:omitidos_dup] += 1
        next
      end

      # Parsear año y mes
      anio = ano_raw.to_s.gsub(/[^0-9]/, "").to_i
      mes  = mes_raw.to_s.gsub(/[^0-9]/, "").to_i
      next if anio < 2020 || mes < 1 || mes > 12

      # Parsear monto: "$200.000" → 200000
      monto_pago = valor_raw.gsub(/[$\s]/, "").gsub(".", "").to_i
      next if monto_pago <= 0

      # Parsear fecha: d/m/yyyy o d/m/yy
      fecha_pago = begin
        parts = fecha_raw.split("/").map { |p| p.strip.to_i }
        if parts.size == 3
          d, m, y = parts
          y += 2000 if y < 100
          Date.new(y, m, d)
        end
      rescue
        nil
      end
      fecha_pago ||= Date.new(anio, mes, 1)

      # Buscar miembro — primero por alias, luego por nombre normalizado
      miembro = Miembro
                  .joins(:user)
                  .where("aliases @> ?", [nombre_hoja].to_json)
                  .first

      unless miembro
        # Intentar por nombre_completo normalizado (usuario: "nombre apellido")
        miembro = Miembro.joins(:user).find { |m|
          m.user.nombre_completo.upcase.strip == nombre_hoja ||
          "#{m.user.apellido} #{m.user.nombre}".upcase.strip == nombre_hoja
        }
      end

      unless miembro
        # Búsqueda parcial: primer apellido + primer nombre
        palabras = nombre_hoja.split
        if palabras.size >= 2
          miembro = Miembro.joins(:user).find { |m|
            u = m.user
            apellido_norm = u.apellido.to_s.upcase.split.first.to_s
            nombre_norm   = u.nombre.to_s.upcase.split.first.to_s
            palabras.include?(apellido_norm) && palabras.include?(nombre_norm)
          }
        end
      end

      unless miembro
        stats[:omitidos_sin_miembro] += 1
        stats[:no_coinciden] << nombre_hoja unless stats[:no_coinciden].include?(nombre_hoja)
        next
      end

      # Registrar alias para futuras sincronizaciones
      miembro.agregar_alias(nombre_hoja)

      logia = miembro.logia

      begin
        ActiveRecord::Base.transaction do
          # Encontrar o crear PeriodoCobro
          periodo = PeriodoCobro.find_by(anio: anio, mes: mes)
          unless periodo
            monto_periodo = logia.monto_mensual > 0 ? logia.monto_mensual : monto_pago
            periodo = PeriodoCobro.new(
              anio:              anio,
              mes:               mes,
              nombre:            "#{PeriodoCobro::MESES[mes]} #{anio}",
              monto:             monto_periodo,
              fecha_vencimiento: Date.new(anio, mes, -1),
              creado_por:        admin
            )
            periodo.save!(validate: false)
          end

          # Encontrar o crear Cobro
          cobro = Cobro.find_by(miembro: miembro, periodo_cobro: periodo)
          unless cobro
            cobro = Cobro.create!(
              miembro:      miembro,
              periodo_cobro: periodo,
              monto:        logia.monto_mensual > 0 ? logia.monto_mensual : monto_pago,
              estado:       :pendiente
            )
          end

          # No reimportar si el cobro ya tiene pago con RC igual
          if cobro.pago&.numero_rc.present? && !rc_pendiente
            stats[:omitidos_dup] += 1
            raise ActiveRecord::Rollback
          end

          # Si ya existe un pago pendiente de RC para este cobro, no duplicar
          if rc_pendiente && cobro.pago.present?
            stats[:omitidos_dup] += 1
            raise ActiveRecord::Rollback
          end

          # Crear Pago sin validación de soporte (importación histórica)
          pago = cobro.build_pago(
            monto_pagado: monto_pago,
            fecha_pago:   fecha_pago,
            metodo_pago:  "consignacion",
            numero_rc:    rc_numero,
            validado_por: rc_pendiente ? nil : admin,
            validado_at:  rc_pendiente ? nil : fecha_pago
          )
          pago.save!(validate: false)

          # Estado del cobro: pagado si tiene RC, soporte_adjunto si RC Pendiente
          rc_pendiente ? cobro.soporte_adjunto! : cobro.pagado!

          rc_pendiente ? stats[:importados_sin_rc] += 1 : stats[:importados] += 1
          print "."
        end
      rescue ActiveRecord::Rollback
        # ya contado como duplicado
      rescue => e
        stats[:errores] += 1
        puts "\nERROR fila #{idx + 1} (#{nombre_hoja} #{rc_numero}): #{e.message}"
      end
    end

    puts "\n\n=== SINCRONIZACIÓN COMPLETADA ==="
    puts "  Importados con RC:         #{stats[:importados]}"
    puts "  Importados sin RC (pend.): #{stats[:importados_sin_rc]}"
    puts "  Omitidos (duplicados):     #{stats[:omitidos_dup]}"
    puts "  Omitidos (sin miembro):    #{stats[:omitidos_sin_miembro]}"
    puts "  Errores:                   #{stats[:errores]}"

    if stats[:no_coinciden].any?
      puts "\n  Nombres sin coincidencia (revisar manualmente):"
      stats[:no_coinciden].each { |n| puts "    - #{n}" }
    end
  end
end
