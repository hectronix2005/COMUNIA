module Denuncias
  class SolicitudRetiro < ApplicationRecord
    self.table_name = "denuncias_solicitudes_retiro"
    belongs_to :reporte
    scope :pendientes, -> { where(estado: "pendiente") }
  end
end
