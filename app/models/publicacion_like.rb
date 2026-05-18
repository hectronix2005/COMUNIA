class PublicacionLike < ApplicationRecord
  belongs_to :publicacion, counter_cache: :likes_count
  belongs_to :user

  validates :user_id, uniqueness: { scope: :publicacion_id }
end
