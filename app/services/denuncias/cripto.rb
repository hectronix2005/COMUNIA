module Denuncias
  # AES-256-GCM con la clave maestra y horas redondeadas. Todo con OpenSSL de la librería estándar
  # (formato: iv(12) || cifrado || tag(16)).
  module Cripto
    class ClaveInvalida < StandardError; end

    IV = 12
    TAG = 16

    module_function

    def importar_clave(base64)
      crudo = Base64.strict_decode64(base64.to_s)
      raise ClaveInvalida, "DENUNCIAS_CLAVE debe ser de 32 bytes en base64" unless crudo.bytesize == 32
      crudo
    rescue ArgumentError
      raise ClaveInvalida, "DENUNCIAS_CLAVE no es base64"
    end

    def clave_maestra
      valor = ENV["DENUNCIAS_CLAVE"].presence
      valor ||= Rails.application.key_generator.generate_key("denuncias/clave-dev", 32).then { Base64.strict_encode64(_1) } if Rails.env.local?
      raise ClaveInvalida, "falta DENUNCIAS_CLAVE" unless valor
      importar_clave(valor)
    end

    def cifrar(datos, clave = clave_maestra)
      c = OpenSSL::Cipher.new("aes-256-gcm").encrypt
      c.key = clave
      iv = c.random_iv
      iv + c.update(datos.b) + c.final + c.auth_tag(TAG)
    end

    def descifrar(datos, clave = clave_maestra)
      datos = datos.b
      c = OpenSSL::Cipher.new("aes-256-gcm").decrypt
      c.key = clave
      c.iv = datos.byteslice(0, IV)
      c.auth_tag = datos.byteslice(-TAG, TAG)
      c.update(datos.byteslice(IV...-TAG)) + c.final
    end

    def cifrar_b64(texto) = Base64.strict_encode64(cifrar(texto))
    def descifrar_b64(b64) = descifrar(Base64.strict_decode64(b64)).force_encoding("UTF-8")

    def sha256_hex(datos) = OpenSSL::Digest::SHA256.hexdigest(datos)

    # Hora UTC redondeada hacia abajo: nunca se guarda el instante exacto.
    def hora_redondeada(t = Time.now)
      t = t.utc
      Time.utc(t.year, t.month, t.day, t.hour)
    end

    # Lo único público de cuándo se denunció: el día en Bogotá (UTC-5, sin horario de verano).
    def fecha_bogota(t) = (t.utc - 5 * 3600).strftime("%Y-%m-%d")
  end
end
