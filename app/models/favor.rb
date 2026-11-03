# Un «pido» o un «ofrezco» entre vecinos: «¿alguien me presta un taladro?», «paseo perros los sábados». Es de la
# organización raíz, lo ve toda la comunidad y vence a los 14 días. Quien puede ayudar responde (FavorRespuesta),
# lo que abre el chat privado con el autor; el autor lo marca resuelto y, si quiere, da las gracias a quien ayudó.
# Para que no se llene, cada persona tiene como mucho 3 abiertos de cada tipo.
class Favor < ApplicationRecord
  TIPOS = %w[pido ofrezco].freeze
  ESTADOS = %w[abierto resuelto cerrado].freeze
  VIGENCIA = 14.days
  MAXIMO_ABIERTOS = 3

  belongs_to :logia
  belongs_to :user
  belongs_to :ayudante, class_name: "User", optional: true
  has_many :favor_respuestas, dependent: :delete_all
  has_many :ayudantes_posibles, through: :favor_respuestas, source: :user

  validates :tipo, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :titulo, presence: true, length: { maximum: 120 }
  validates :detalle, length: { maximum: 1000 }
  validate :no_mas_de_tres_abiertos, on: :create

  scope :de_logias, ->(ids) { where(logia_id: ids) }
  scope :vigentes, -> { where(estado: "abierto").where(created_at: VIGENCIA.ago..) }
  scope :pidos, -> { where(tipo: "pido") }
  scope :ofrezcos, -> { where(tipo: "ofrezco") }
  scope :recientes, -> { order(created_at: :desc) }

  def pido? = tipo == "pido"
  def abierto? = estado == "abierto"
  def vigente? = abierto? && created_at > VIGENCIA.ago
  def vence_el = created_at + VIGENCIA

  def respondido_por?(user) = favor_respuestas.exists?(user_id: user.id)

  def resolver!(ayudante: nil)
    update!(estado: "resuelto", resuelto_at: Time.current, ayudante:)
  end

  def etiqueta = pido? ? "Pide" : "Ofrece"

  private

  def no_mas_de_tres_abiertos
    return unless user && tipo.in?(TIPOS)
    return if Favor.vigentes.where(user:, tipo:).count < MAXIMO_ABIERTOS

    errors.add(:base, "Ya tienes #{MAXIMO_ABIERTOS} #{pido? ? 'pedidos' : 'ofertas'} abiertos. Marca alguno como resuelto o ciérralo antes de publicar otro.")
  end
end
