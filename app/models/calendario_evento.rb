class CalendarioEvento < ApplicationRecord
  COLORES = {
    "Arándano"  => "#4285f4",
    "Tomate"    => "#d50000",
    "Tangerina" => "#f4511e",
    "Banana"    => "#f6bf26",
    "Salvia"    => "#33b679",
    "Albahaca"  => "#0b8043",
    "Pavo Real" => "#039be5",
    "Uva"       => "#8e24aa",
    "Lavanda"   => "#7986cb",
    "Flamingo"  => "#e67c73",
    "Grafito"   => "#616161"
  }.freeze

  RECURRENCIA_TIPOS = {
    "diaria"   => "Diariamente",
    "semanal"  => "Semanalmente",
    "mensual"  => "Mensualmente",
    "anual"    => "Anualmente"
  }.freeze

  DIAS_SEMANA = %w[L M X J V S D].freeze  # 0=Lun … 6=Dom (ISO)

  belongs_to :logia
  belongs_to :user
  belongs_to :serie,    class_name: "CalendarioEvento", optional: true,
                        foreign_key: :serie_id
  has_many   :instancias, class_name: "CalendarioEvento", foreign_key: :serie_id,
                          dependent: :delete_all

  validates :titulo, presence: true, length: { maximum: 200 }
  validates :inicio, presence: true
  validates :fin,    presence: true
  validate  :fin_posterior_al_inicio

  scope :en_rango,   ->(desde, hasta) { where("inicio < ? AND fin > ?", hasta, desde) }
  scope :de_logias,  ->(ids) { where(logia_id: Array(ids)) }
  scope :ordenados,  -> { order(:inicio) }
  scope :maestros,   -> { where(serie_id: nil) }  # parent or non-recurring

  after_create_commit :generar_instancias, if: :recurrente?

  def recurrente?
    recurrencia_tipo.present? && serie_id.nil?
  end

  def instancia_de_serie?
    serie_id.present?
  end

  def multidia?
    fin.to_date > inicio.to_date
  end

  def resumen_recurrencia
    return nil unless recurrencia_tipo.present?

    tipo  = RECURRENCIA_TIPOS[recurrencia_tipo] || recurrencia_tipo
    inter = recurrencia_intervalo.to_i
    base  = inter > 1 ? "Cada #{inter} #{unidad_plural(recurrencia_tipo, inter)}" : tipo

    if recurrencia_dias.present? && recurrencia_tipo == "semanal"
      dias = recurrencia_dias.split(",").map { |d| DIAS_SEMANA[d.to_i] }.join(", ")
      base += " (#{dias})"
    end

    case recurrencia_fin
    when "fecha"
      base += " hasta #{recurrencia_hasta&.strftime('%d/%m/%Y')}"
    when "ocurrencias"
      base += ", #{recurrencia_count} veces"
    end

    base
  end

  # ── Recurrence generation ──────────────────────────────────────
  def generar_instancias
    duracion_seg = (fin - inicio).to_i
    limite_fecha = limite_de_fecha
    max_extra    = recurrencia_fin == "ocurrencias" ? recurrencia_count.to_i - 1 : 364

    actual    = inicio
    generadas = 0

    loop do
      break if generadas >= [max_extra, 364].min

      siguiente = siguiente_ocurrencia_despues(actual)
      break if siguiente.nil?
      break if limite_fecha && siguiente.to_date > limite_fecha

      CalendarioEvento.create!(
        titulo:      titulo,
        descripcion: descripcion,
        inicio:      siguiente,
        fin:         siguiente + duracion_seg.seconds,
        todo_el_dia: todo_el_dia,
        color:       color,
        ubicacion:   ubicacion,
        logia_id:    logia_id,
        user_id:     user_id,
        serie_id:    id
      )

      actual    = siguiente
      generadas += 1
    end
  end

  # Remove all instances, re-generate from current attributes
  def regenerar_instancias!
    instancias.delete_all
    generar_instancias if recurrente?
  end

  private

  def fin_posterior_al_inicio
    return unless inicio.present? && fin.present?
    errors.add(:fin, "debe ser igual o posterior al inicio") if fin < inicio
  end

  def limite_de_fecha
    case recurrencia_fin
    when "fecha"       then recurrencia_hasta
    when "ocurrencias" then nil
    else                    inicio.to_date + 1.year
    end
  end

  def siguiente_ocurrencia_despues(dt)
    intervalo = [recurrencia_intervalo.to_i, 1].max

    case recurrencia_tipo
    when "diaria"
      dt + intervalo.days

    when "semanal"
      if recurrencia_dias.present?
        dias_iso = recurrencia_dias.split(",").map(&:to_i).sort
        candidato = dt + 1.day
        tope      = dt + (intervalo * 7 + 1).days
        while candidato <= tope
          wday_iso = candidato.to_date.wday == 0 ? 6 : candidato.to_date.wday - 1
          return candidato if dias_iso.include?(wday_iso)
          candidato += 1.day
        end
        nil
      else
        dt + (intervalo * 7).days
      end

    when "mensual"
      dt + intervalo.months

    when "anual"
      dt + intervalo.years

    else
      nil
    end
  end

  def unidad_plural(tipo, n)
    case tipo
    when "diaria"  then n == 1 ? "día"  : "días"
    when "semanal" then n == 1 ? "semana" : "semanas"
    when "mensual" then n == 1 ? "mes"  : "meses"
    when "anual"   then n == 1 ? "año"  : "años"
    end
  end
end
