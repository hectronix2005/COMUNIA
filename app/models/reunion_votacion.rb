# Una decisión que se vota en una reunión. Votan los convocados, una vez cada uno (se puede cambiar el voto
# mientras está abierta). Se aprueba si hay más «sí» que «no».
class ReunionVotacion < ApplicationRecord
  belongs_to :reunion
  belongs_to :user
  has_many :reunion_votos, dependent: :delete_all

  enum :estado, { abierta: 0, cerrada: 1 }

  validates :pregunta, presence: true, length: { maximum: 300 }

  def totales = ReunionVoto.opciones.keys.index_with(0).merge(reunion_votos.group(:opcion).count)
  def aprobada? = totales["si"] > totales["no"]
  def voto_de(miembro) = miembro && reunion_votos.find_by(miembro: miembro)&.opcion

  # Participación: votos sobre convocados (en %, redondeado).
  def participacion
    total = reunion.convocados.count
    total.zero? ? 0 : (reunion_votos.count * 100.0 / total).round
  end
end
