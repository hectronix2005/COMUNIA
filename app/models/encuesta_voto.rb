class EncuestaVoto < ApplicationRecord
  belongs_to :encuesta_opcion
  belongs_to :user

  validates :user_id, uniqueness: { scope: :encuesta_opcion_id }
end
