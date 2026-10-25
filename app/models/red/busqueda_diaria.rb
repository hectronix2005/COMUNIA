module Red
  # Métrica: cuántas búsquedas hubo cada día. No se guarda qué se buscó ni quién.
  class BusquedaDiaria < ApplicationRecord
    def self.contar!(con_cuenta:)
      columna = con_cuenta ? "con_cuenta" : "sin_cuenta"
      upsert_all([{ fecha: Date.current, columna.to_sym => 1 }], unique_by: :fecha,
                 on_duplicate: Arel.sql("#{columna} = red_busquedas_diarias.#{columna} + 1"))
    end
  end
end
