class NegocioConversacion < ApplicationRecord
  self.table_name = "negocio_conversacions"

  belongs_to :negocio_anuncio
  belongs_to :comprador, class_name: "User"
  belongs_to :vendedor, class_name: "User"
  has_many :mensajes, -> { order(created_at: :asc) },
            class_name: "NegocioMensaje",
            foreign_key: :negocio_conversacion_id,
            dependent: :destroy

  validates :comprador_id, uniqueness: { scope: [:negocio_anuncio_id] }
  validate  :comprador_no_es_vendedor

  scope :de_usuario, ->(u) { where("comprador_id = :id OR vendedor_id = :id", id: u.id) }
  scope :ordenadas,  -> { order(Arel.sql("COALESCE(ultimo_mensaje_at, created_at) DESC")) }

  def otro_usuario(user)
    user.id == comprador_id ? vendedor : comprador
  end

  def no_leidos_para(user)
    mensajes.where(leido: false).where.not(user_id: user.id).count
  end

  private

  def comprador_no_es_vendedor
    errors.add(:comprador_id, "no puede ser igual al vendedor") if comprador_id == vendedor_id
  end
end
