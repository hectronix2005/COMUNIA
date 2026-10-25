module Red
  class Mensaje < ApplicationRecord
    TIPOS = %w[texto contacto_compartido sistema].freeze

    belongs_to :conversacion, class_name: "Red::Conversacion", touch: :ultimo_mensaje_at
    belongs_to :user, optional: true
    has_many :reportes, as: :objeto, class_name: "Red::Reporte", dependent: :delete_all

    validates :tipo, inclusion: { in: TIPOS }
    validates :cuerpo, presence: true, length: { maximum: 2000 }
  end
end
