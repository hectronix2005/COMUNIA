module Red
  # Foto diaria de la confianza de una persona (la calcula Red::CalculoConfianza). Es lo único de sus
  # comunidades que se enseña hacia fuera, y nunca con el puntaje: solo nivel, cuántas y una banda.
  class Confianza < ApplicationRecord
    belongs_to :user

    def self.de(user) = find_by(user_id: user.id) || new(user: user, nivel: 0, comunidades: 0, banda_miembros: "ninguno")

    def nivel_texto = NIVELES.fetch(nivel)

    def banda_texto = BANDAS.fetch(banda_miembros)
  end
end
