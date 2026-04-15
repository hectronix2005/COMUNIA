class Tarifa < ApplicationRecord
  belongs_to :logia
  belongs_to :creado_por, class_name: "User"

  validates :monto, presence: true, numericality: { greater_than: 0 }
  validates :vigente_desde, presence: true
  validates :vigente_hasta, presence: true
  validate :hasta_despues_de_desde
  validate :rango_no_se_superpone

  scope :vigentes, -> { where("vigente_hasta >= ?", Date.current) }
  scope :ordenadas, -> { order(vigente_desde: :desc) }
  scope :historicas, -> { where("vigente_hasta < ?", Date.current) }

  # Encuentra la tarifa vigente para una fecha dada
  def self.vigente_para(fecha)
    where("vigente_desde <= ? AND vigente_hasta >= ?", fecha, fecha)
      .order(vigente_desde: :desc)
      .first
  end

  def vigente?
    vigente_hasta >= Date.current
  end

  def rango_texto
    "#{I18n.l(vigente_desde, format: :short) rescue vigente_desde} - #{I18n.l(vigente_hasta, format: :short) rescue vigente_hasta}"
  end

  # Snapshot de conceptos actuales de la logia
  def self.snapshot_desglose(logia)
    logia.conceptos_cobro.activos.ordenados.map do |c|
      {
        nombre: c.nombre,
        monto: c.monto.to_f,
        tipo: c.tipo,
        monto_por_miembro: c.monto_por_miembro.to_f
      }
    end
  end

  private

  def hasta_despues_de_desde
    return unless vigente_desde && vigente_hasta
    if vigente_hasta < vigente_desde
      errors.add(:vigente_hasta, "debe ser igual o posterior a la fecha de inicio")
    end
  end

  def rango_no_se_superpone
    return unless logia && vigente_desde && vigente_hasta

    # Buscar tarifas de la misma logia que se superpongan en rango de meses
    conflicto = logia.tarifas.where.not(id: id)
      .where("vigente_desde <= ? AND vigente_hasta >= ?", vigente_hasta, vigente_desde)

    if conflicto.exists?
      meses = conflicto.map { |t| t.rango_texto }.join(", ")
      errors.add(:base, "El rango se superpone con otra(s) tarifa(s): #{meses}")
    end
  end
end
