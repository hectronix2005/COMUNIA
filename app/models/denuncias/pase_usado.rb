module Denuncias
  # Solo sha256(msg), como clave primaria y nada más: ni fecha ni id secuencial.
  class PaseUsado < ApplicationRecord
    self.table_name = "denuncias_pases_usados"
    self.primary_key = "sha256"

    # true si se marcó ahora; false si ya estaba usado.
    def self.marcar(sha256)
      insert_all([{ sha256: sha256 }], unique_by: :sha256, returning: [:sha256]).rows.any?
    end
  end
end
