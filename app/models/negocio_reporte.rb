class NegocioReporte < ApplicationRecord
  MOTIVOS = %w[spam fraude inapropiado prohibido duplicado otro].freeze
  MOTIVO_LABEL = {
    "spam"        => "Spam",
    "fraude"      => "Posible fraude / estafa",
    "inapropiado" => "Contenido inapropiado",
    "prohibido"   => "Artículo prohibido",
    "duplicado"   => "Duplicado",
    "otro"        => "Otro"
  }.freeze

  belongs_to :negocio_anuncio
  belongs_to :user

  validates :motivo, presence: true, inclusion: { in: MOTIVOS }
  validates :user_id, uniqueness: { scope: :negocio_anuncio_id, message: "ya reportaste este anuncio" }
end
