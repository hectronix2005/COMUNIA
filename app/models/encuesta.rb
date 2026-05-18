class Encuesta < ApplicationRecord
  belongs_to :user
  belongs_to :logia

  has_many :encuesta_opciones, -> { order(:posicion) }, dependent: :destroy
  has_many :encuesta_votos, through: :encuesta_opciones

  accepts_nested_attributes_for :encuesta_opciones, reject_if: :all_blank, allow_destroy: true

  enum :estado, { activa: 0, cerrada: 1 }

  validates :titulo, presence: true
  validates :encuesta_opciones, length: { minimum: 2, message: "debe tener al menos 2 opciones" }

  def total_votos
    encuesta_votos.count
  end

  def usuario_voto?(user)
    encuesta_votos.exists?(user_id: user.id)
  end

  def cerrada_o_expirada?
    cerrada? || (cierre_en.present? && cierre_en <= Time.current)
  end
end
