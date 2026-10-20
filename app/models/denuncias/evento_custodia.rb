module Denuncias
  # Solo inserción: los triggers de la base abortan cualquier UPDATE, DELETE o TRUNCATE.
  class EventoCustodia < ApplicationRecord
    self.table_name = "denuncias_eventos_custodia"
    self.primary_key = "n"
    def readonly? = persisted?
  end
end
