class NegocioFavorito < ApplicationRecord
  belongs_to :user
  belongs_to :negocio_anuncio

  validates :user_id, uniqueness: { scope: :negocio_anuncio_id }
end
