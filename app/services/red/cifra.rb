module Red
  # Cifra lo poco que se guarda de quien escribe sin cuenta (su medio de contacto). La clave se deriva
  # de secret_key_base: no hay que añadir credenciales nuevas.
  module Cifra
    module_function

    def cifrador
      clave = Rails.application.key_generator.generate_key("red/contacto-externo", 32)
      ActiveSupport::MessageEncryptor.new(clave, cipher: "aes-256-gcm")
    end

    def cifrar(texto) = cifrador.encrypt_and_sign(texto.to_s)

    def descifrar(cif)
      cifrador.decrypt_and_verify(cif)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    # Huella de una IP para contar votos (reportes) sin guardarla.
    def huella_ip(ip) = "ip:" + OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("red/huella-ip", 32), ip.to_s)
  end
end
