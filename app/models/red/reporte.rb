module Red
  # Reporte de una publicación, un perfil o un mensaje. Cada persona (o IP, por HMAC) cuenta una vez.
  # Con OCULTAR_CON reportes pendientes de personas distintas, lo reportado pasa a revisión hasta que
  # un moderador decide.
  class Reporte < ApplicationRecord
    MOTIVOS = {
      "estafa" => "Posible estafa o fraude", "spam" => "Spam o publicidad engañosa",
      "ofensivo" => "Ofensivo, acoso o discriminación", "falso" => "Información falsa o suplantación",
      "datos_personales" => "Expone datos personales de alguien", "otro" => "Otro motivo"
    }.freeze
    ESTADOS = %w[pendiente descartado sancionado].freeze
    OCULTAR_CON = 3

    belongs_to :objeto, polymorphic: true
    belongs_to :reportante, class_name: "User", optional: true
    belongs_to :resuelto_por, class_name: "User", optional: true

    validates :motivo, inclusion: { in: MOTIVOS.keys }
    validates :estado, inclusion: { in: ESTADOS }
    validates :detalle, length: { maximum: 1000 }
    validates :huella, uniqueness: { scope: %i[objeto_type objeto_id] }
    validates :objeto_type, inclusion: { in: %w[Red::Publicacion Red::Perfil Red::Mensaje] }

    scope :pendientes, -> { where(estado: "pendiente") }

    def motivo_texto = MOTIVOS.fetch(motivo)

    # Usuario del objeto reportado (a quien se sanciona si procede).
    def responsable
      case objeto
      when Red::Publicacion, Red::Perfil, Red::Mensaje then objeto.user
      end
    end
  end
end
