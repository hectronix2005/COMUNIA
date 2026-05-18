class EncuestaOpcion < ApplicationRecord
  belongs_to :encuesta

  has_many :encuesta_votos, dependent: :destroy

  validates :texto, presence: true

  def votos_count
    encuesta_votos.count
  end

  def porcentaje(total)
    return 0 if total.zero?
    (votos_count.to_f / total * 100).round(1)
  end
end
