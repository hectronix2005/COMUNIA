class ReunionAsistencia < ApplicationRecord
  belongs_to :reunion
  belongs_to :miembro

  validates :miembro_id, uniqueness: { scope: :reunion_id }
end
