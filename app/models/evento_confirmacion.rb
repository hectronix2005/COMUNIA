class EventoConfirmacion < ApplicationRecord
  belongs_to :calendario_evento
  belongs_to :user

  enum :estado, { pendiente: 0, confirmado: 1, rechazado: 2 }

  validates :user_id, uniqueness: { scope: :calendario_evento_id }

  scope :confirmados, -> { where(estado: :confirmado) }
  scope :rechazados,  -> { where(estado: :rechazado) }
end
