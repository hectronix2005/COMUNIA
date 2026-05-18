class PublicacionComentario < ApplicationRecord
  belongs_to :publicacion, counter_cache: :comentarios_count
  belongs_to :user

  validates :contenido, presence: true, length: { maximum: 1000 }
end
