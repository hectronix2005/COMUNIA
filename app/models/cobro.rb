class Cobro < ApplicationRecord
  enum :estado, { pendiente: 0, soporte_adjunto: 1, pagado: 2, vencido: 3 }

  belongs_to :periodo_cobro
  belongs_to :miembro
  has_one :pago, dependent: :destroy

  validates :monto, presence: true, numericality: { greater_than: 0 }
  validates :miembro_id, uniqueness: { scope: :periodo_cobro_id }

  scope :por_estado, ->(estado) { where(estado: estado) if estado.present? }
  scope :por_logia, ->(logia_id) { joins(:miembro).where(miembros: { logia_id: logia_id }) if logia_id.present? }
  scope :pendientes_o_vencidos, -> { where(estado: [:pendiente, :vencido]) }
  scope :recientes, -> { order(created_at: :desc) }

  delegate :nombre_completo, to: :miembro, prefix: true

  def puede_adjuntar_soporte?
    pendiente? || vencido?
  end

  def puede_validar?
    soporte_adjunto?
  end

  def logia
    miembro.logia
  end
end
