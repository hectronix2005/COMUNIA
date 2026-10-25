module Red
  # Una persona deja de recibir mensajes de otra.
  class Bloqueo < ApplicationRecord
    belongs_to :user
    belongs_to :bloqueado, class_name: "User"

    def self.entre?(a, b) = where(user_id: a.id, bloqueado_id: b.id).or(where(user_id: b.id, bloqueado_id: a.id)).exists?
  end
end
