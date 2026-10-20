module Denuncias
  class Evidencia < ApplicationRecord
    self.table_name = "denuncias_evidencias"
    belongs_to :reporte
    def extension = mime == "image/png" ? "png" : "jpg"
  end
end
