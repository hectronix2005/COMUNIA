module Denuncias
  # Verificación de los pases anónimos de COMUNIA (contrato v2): RSABSSA-SHA384-PSS-Randomized.
  # Verificar = RSA-PSS SHA-384, sal de 48 y MGF1-SHA384 sobre el msg preparado de 64 bytes.
  # Las claves se toman de claves.json tal como se publica y con las mismas reglas estrictas de
  # DENUNCIAPP: un archivo con cualquier anomalía se rechaza entero y se conservan las últimas
  # buenas. Nada del pase (kid, msg, firma, hora) se guarda con la denuncia: solo sha256(msg)
  # en denuncias_pases_usados, para no aceptarlo dos veces.
  module Pases
    class ClavesInvalidas < StandardError; end

    BITS_MINIMOS = 2048
    LARGO_MSG = 64
    MAX_PASE = 4096
    GRACIA = 31 * 24 * 3600 # si la lectura falla, una clave vencida no vale más de un mes

    Clave = Data.define(:kid, :pkey, :bits, :desde, :hasta)
    Estado = Data.define(:claves, :sello_publico)

    module_function

    def b64url(texto)
      raise ArgumentError unless texto.is_a?(String) && texto.match?(/\A[A-Za-z0-9_-]*\z/) && texto.size % 4 != 1
      Base64.urlsafe_decode64(texto + "=" * ((4 - texto.size % 4) % 4))
    end

    def solo_campos?(obj, campos) = obj.is_a?(Hash) && obj.keys.sort == campos.sort

    # Valida un claves.json ya parseado → Estado. Lanza ClavesInvalidas ante cualquier anomalía.
    def leer_claves(json)
      raise ClavesInvalidas, "formato" unless solo_campos?(json, %w[claves sello_publico])
      raise ClavesInvalidas, "sello_publico no es booleano" unless [true, false].include?(json["sello_publico"])
      lista = json["claves"]
      raise ClavesInvalidas, "debe haber 1 o 2 claves" unless lista.is_a?(Array) && lista.size.between?(1, 2)

      claves = lista.map do |c|
        raise ClavesInvalidas, "campos de la clave" unless solo_campos?(c, %w[kid n e desde hasta])
        raise ClavesInvalidas, "e distinto de 65537" unless c["e"] == "AQAB"
        raise ClavesInvalidas, "clave" unless c["n"].is_a?(String) && c["kid"].is_a?(String)
        n = OpenSSL::BN.new(b64url(c["n"]), 2)
        raise ClavesInvalidas, "clave de #{n.num_bits} bits" if n.num_bits < BITS_MINIMOS
        desde, hasta = Time.iso8601(c["desde"].to_s), Time.iso8601(c["hasta"].to_s)
        raise ClavesInvalidas, "vigencia vacía" unless desde < hasta
        pkey = OpenSSL::PKey::RSA.new(OpenSSL::ASN1::Sequence([OpenSSL::ASN1::Integer(n), OpenSSL::ASN1::Integer(65_537)]).to_der)
        kid = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(pkey.public_to_der), padding: false)
        raise ClavesInvalidas, "kid no corresponde a la clave" unless kid == c["kid"]
        Clave.new(kid: kid, pkey: pkey, bits: n.num_bits, desde: desde, hasta: hasta)
      end.sort_by(&:desde)

      if claves.size == 2
        raise ClavesInvalidas, "kid repetido" if claves[0].kid == claves[1].kid
        raise ClavesInvalidas, "vigencias solapadas" if claves[0].hasta > claves[1].desde
      end
      Estado.new(claves: claves, sello_publico: json["sello_publico"])
    rescue ArgumentError, OpenSSL::PKey::PKeyError, OpenSSL::BNError
      raise ClavesInvalidas, "valor no válido"
    end

    # Claves vigentes. Se leen de lo que COMUNIA publica en /pases/claves.json (misma app) con un
    # temporizador de una hora, nunca a raíz de una denuncia. Un archivo malo no pisa al bueno.
    class Almacen
      def initialize(fuente: -> { JSON.parse({ claves: ::Pases::Claves.publicadas.map(&:jwk), sello_publico: ::Pases.sello_publico? }.to_json) },
                     reloj: -> { Time.now }, cada: 3600)
        @fuente, @reloj, @cada = fuente, reloj, cada
        @estado = Estado.new(claves: [], sello_publico: false)
        @mutex = Mutex.new
        @leido = nil
      end

      def refrescar
        nuevo = Pases.leer_claves(@fuente.call)
        @mutex.synchronize { @estado = nuevo }
        true
      rescue StandardError => e
        Rails.logger.warn("denuncias: claves de pases no actualizadas (#{e.class})")
        false
      ensure
        @leido = @reloj.call
      end

      def estado
        refrescar if @leido.nil? || @reloj.call - @leido >= @cada
        @estado
      end

      def sello_publico? = estado.sello_publico

      def clave(kid)
        ahora = @reloj.call
        estado.claves.find { |c| c.kid == kid && c.desde <= ahora && ahora < c.hasta + GRACIA }
      end
    end

    mattr_accessor :almacen
    def almacen_global = (self.almacen ||= Almacen.new)

    # → sha256(msg) en hex si el pase es válido; nil si no.
    def verificar(texto, almacen = almacen_global)
      return nil unless texto.is_a?(String) && texto.size.between?(1, MAX_PASE)

      pase = JSON.parse(b64url(texto).force_encoding("UTF-8").tap { raise ArgumentError unless _1.valid_encoding? })
      return nil unless solo_campos?(pase, %w[kid msg firma]) && pase.values.all?(String)

      clave = almacen.clave(pase["kid"]) or return nil
      msg, firma = b64url(pase["msg"]), b64url(pase["firma"])
      return nil unless msg.bytesize == LARGO_MSG && firma.bytesize == (clave.bits + 7) / 8
      return nil unless clave.pkey.verify_pss("SHA384", firma, msg, salt_length: 48, mgf1_hash: "SHA384")

      Cripto.sha256_hex(msg)
    rescue ArgumentError, JSON::ParserError, OpenSSL::PKey::PKeyError
      nil
    end
  end
end
