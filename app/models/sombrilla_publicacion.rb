# Publicación en el muro de una sombrilla.
class SombrillaPublicacion < ApplicationRecord
  self.table_name = "sombrilla_publicaciones"
  include ContenidoDeSombrilla
  include AttachmentValidations

  belongs_to :sombrilla
  has_many :comentarios, class_name: "SombrillaComentario", foreign_key: :publicacion_id, inverse_of: :publicacion,
                         dependent: :destroy
  has_many_attached :imagenes

  validates :contenido, presence: true, length: { maximum: 3000 }
  validates :imagenes, length: { maximum: 4, message: "máximo 4 imágenes" }
  # Fotos, sin SVG: un SVG puede llevar código.
  validates_attachment :imagenes, types: %w[image/png image/jpeg image/webp image/gif], multi: true

  scope :recientes, -> { order(created_at: :desc) }

  def sombrilla_de = sombrilla
end
