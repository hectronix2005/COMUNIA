module Red
  # Reseña verificable: solo se escribe tras una conversación real en COMUNIA (Conversacion#resenable_por?).
  class Resena < ApplicationRecord
    belongs_to :conversacion, class_name: "Red::Conversacion"
    belongs_to :autor, class_name: "User"
    belongs_to :sujeto, class_name: "User"

    validates :puntaje, inclusion: { in: 1..5 }
    validates :comentario, length: { maximum: 1000 }
    validates :respuesta, length: { maximum: 1000 }
    validates :autor_id, uniqueness: { scope: :conversacion_id }

    def self.resumen_de(user)
      fila = where(sujeto_id: user.id).pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(puntaje)"))
      { total: fila[0].to_i, promedio: fila[1]&.to_f&.round(1) }
    end
  end
end
