class PeriodoCobro < ApplicationRecord
  MESES = {
    1 => "Enero", 2 => "Febrero", 3 => "Marzo", 4 => "Abril",
    5 => "Mayo", 6 => "Junio", 7 => "Julio", 8 => "Agosto",
    9 => "Septiembre", 10 => "Octubre", 11 => "Noviembre", 12 => "Diciembre"
  }.freeze

  enum :estado, { activo: 0, cerrado: 1 }

  # La organización (logia raíz) del periodo: sus cobros son de los miembros de ella y de sus logias.
  belongs_to :tenant, class_name: "Logia"
  belongs_to :creado_por, class_name: "User"
  has_many :cobros, dependent: :destroy

  validates :nombre, presence: true
  validates :anio, presence: true, numericality: { greater_than: 2020 }
  validates :mes, presence: true, inclusion: { in: 1..12 }
  validates :monto, presence: true, numericality: { greater_than: 0 }
  validates :fecha_vencimiento, presence: true
  validates :anio, uniqueness: { scope: [:tenant_id, :mes], message: "ya existe un periodo para este mes/anio" }
  validate { errors.add(:tenant, "debe ser una organización, no una logia hija") if tenant&.tenant_id }

  scope :recientes, -> { order(anio: :desc, mes: :desc) }
  scope :activos, -> { where(estado: :activo) }
  scope :de_organizacion, ->(raiz) { where(tenant: raiz) }

  before_validation :generar_nombre

  def nombre_mes
    MESES[mes]
  end

  def generar_cobros!
    fecha_periodo = Date.new(anio, mes, 1)

    cobrables = Miembro.includes(:logia).where(logia_id: logia_ids).select { |m| m.cobrable_en?(fecha_periodo) }

    # Pre-calcular cuota por logia con el conteo real del período
    cuota_por_logia = cobrables.group_by(&:logia_id).transform_values do |miembros_logia|
      logia = miembros_logia.first.logia
      tarifa = logia.tarifa_vigente(fecha_periodo)
      tarifa ? tarifa.monto : logia.monto_mensual_para_conteo(miembros_logia.size)
    end

    cobrables.each do |miembro|
      cobros.find_or_create_by!(miembro: miembro) do |cobro|
        # Una logia sin tarifa ni desglose da cuota 0: entonces vale el monto del periodo.
        cuota = cuota_por_logia[miembro.logia_id].to_d
        cobro.monto = cuota.positive? ? cuota : monto
      end
    end
  end

  def logia_ids
    [tenant_id, *Logia.where(tenant_id: tenant_id).ids]
  end

  private

  def generar_nombre
    self.nombre = "#{MESES[mes]} #{anio}" if mes.present? && anio.present?
  end
end
