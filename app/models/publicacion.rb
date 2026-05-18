class Publicacion < ApplicationRecord
  belongs_to :user
  belongs_to :logia

  has_many :publicacion_comentarios, dependent: :destroy
  has_many :publicacion_likes, dependent: :destroy
  has_many_attached :imagenes

  validates :contenido, presence: true, length: { maximum: 5000 }
  validates :imagenes, length: { maximum: 4, message: "máximo 4 imágenes" }

  scope :recientes,  -> { order(fijada: :desc, created_at: :desc) }
  scope :de_logias,  ->(ids) { where(logia_id: ids) }

  def liked_by?(user)
    publicacion_likes.exists?(user_id: user.id)
  end
end
