module Denuncias
  # Oculta cédulas y teléfonos del texto público (el original queda cifrado como evidencia).
  # Una secuencia de 7 o más dígitos, aunque vaya con puntos, guiones, espacios o un +57 delante,
  # se reemplaza; no si va precedida de «$» (es un monto). Direcciones y placas tienen menos dígitos.
  module Filtro
    DATO_OCULTO = "[dato oculto]".freeze
    SECUENCIA = /(\$\s*)?(\+?\d[\d.\- ]*\d)/

    def self.ocultar(texto)
      ocultos = 0
      limpio = texto.gsub(SECUENCIA) do |todo|
        pesos, numero = Regexp.last_match(1), Regexp.last_match(2)
        if pesos || numero.count("0-9") < 7
          todo
        else
          ocultos += 1
          DATO_OCULTO
        end
      end
      [limpio, ocultos]
    end
  end
end
