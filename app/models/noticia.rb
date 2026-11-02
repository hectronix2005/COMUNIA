# Una noticia de internet sobre una comunidad (siempre la organización, no sus grupos). La trae
# ActualizarNoticiasJob de Google Noticias con las búsquedas que eligió su admin; solo se guarda el
# titular, el medio, la fecha y el enlace al artículo. El admin puede ocultar la que no sirva.
class Noticia < ApplicationRecord
  self.table_name = "noticias"
  belongs_to :logia

  # Cuántas se guardan por comunidad y cuántos días duran.
  MAXIMO = 60
  DIAS = 30

  validates :titulo, presence: true, length: { maximum: 300 }
  validates :medio, length: { maximum: 120 }
  validates :url, presence: true, length: { maximum: 2000 }, format: { with: %r{\Ahttps://\S+\z} }

  scope :visibles, -> { where(oculta: false) }
  scope :recientes, -> { order(publicada_en: :desc) }
end
