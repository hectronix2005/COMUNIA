# Alguien que dijo «puedo ayudar» a un Favor: una vez por persona. Sirve para que el autor elija a quién dar las
# gracias al resolverlo.
class FavorRespuesta < ApplicationRecord
  belongs_to :favor
  belongs_to :user

  validates :user_id, uniqueness: { scope: :favor_id }
end
