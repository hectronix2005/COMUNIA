# Comentario a una publicación de una sombrilla.
class SombrillaComentario < ApplicationRecord
  self.table_name = "sombrilla_comentarios"
  include ContenidoDeSombrilla

  belongs_to :publicacion, class_name: "SombrillaPublicacion", inverse_of: :comentarios

  validates :contenido, presence: true, length: { maximum: 1000 }

  def sombrilla_de = publicacion.sombrilla
end
