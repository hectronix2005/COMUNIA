module Denuncias
  class Recompensa < ApplicationRecord
    self.table_name = "denuncias_recompensas"
    scope :publicadas, -> { where(estado: "publicada").order(creado_en: :desc) }

    def a_publico
      { id: id, titulo: titulo, entidad: entidad, montoTexto: monto_texto, fuenteUrl: fuente_url,
        vigenteHasta: vigente_hasta&.iso8601 }
    end
  end
end
