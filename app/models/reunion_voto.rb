class ReunionVoto < ApplicationRecord
  belongs_to :reunion_votacion
  belongs_to :miembro

  enum :opcion, { si: 0, no: 1, abstencion: 2 }

  validates :miembro_id, uniqueness: { scope: :reunion_votacion_id }
end
