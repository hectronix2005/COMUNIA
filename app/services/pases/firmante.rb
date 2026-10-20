module Pases
  # BlindSign de RFC 9474 §4.3: RSASP1 sobre el mensaje cegado y comprobación de
  # la firma antes de devolverla (protege la clave de fallos de cálculo). Usa
  # OpenSSL sin relleno, que firma con CRT y blinding; nada de aritmética propia.
  class Firmante
    class Error < StandardError; end

    # El mensaje cegado tiene que medir lo mismo que el módulo y ser menor que él.
    def self.valido?(clave, cegado)
      cegado.is_a?(String) && cegado.bytesize == clave.tamano &&
        OpenSSL::BN.new(cegado, 2) < clave.pkey.n
    end

    def self.firmar(clave, cegado)
      raise Error, "mensaje cegado inválido" unless valido?(clave, cegado)

      firma = clave.pkey.sign_raw(nil, cegado, rsa_padding_mode: "none")
      unless clave.pkey.verify_raw(nil, firma, cegado, rsa_padding_mode: "none")
        raise Error, "la firma no se verifica"
      end
      firma
    rescue OpenSSL::PKey::PKeyError
      raise Error, "OpenSSL rechazó el mensaje"
    end
  end
end
