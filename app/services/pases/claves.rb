module Pases
  # Una clave RSA por mes UTC («época»), la misma para todos los miembros de
  # todas las logias. Las privadas viven en PASES_DIR como AAAA-MM.pem; las
  # genera el cron del host (config/deploy/asus/pases-claves.sh) y la app solo
  # las lee. Se publican la del mes en curso y la del anterior; la del mes
  # siguiente ya existe pero no se publica hasta su «desde».
  class Claves
    BITS_MINIMOS = 2048
    EXPONENTE = 65_537

    Clave = Data.define(:pkey, :desde, :hasta) do
      def kid = Pases.b64(OpenSSL::Digest::SHA256.digest(pkey.public_to_der))
      def tamano = pkey.n.num_bytes

      def jwk
        { kid: kid, n: Pases.b64(pkey.n.to_s(2)), e: Pases.b64(pkey.e.to_s(2)),
          desde: desde.iso8601, hasta: hasta.iso8601 }
      end
    end

    def self.dir
      Pathname(ENV["PASES_DIR"].presence || Rails.root.join("tmp/pases"))
    end

    # Con la que se firma: solo la del mes en curso.
    def self.actual(ahora = Time.now.utc) = de_la_epoca(inicio_de_mes(ahora))

    # Las que se publican: la del mes anterior y la del mes en curso.
    def self.publicadas(ahora = Time.now.utc)
      inicio = inicio_de_mes(ahora)
      [de_la_epoca(inicio.prev_month), de_la_epoca(inicio)].compact
    end

    def self.de_la_epoca(desde)
      ruta = dir.join("#{desde.strftime('%Y-%m')}.pem")
      return unless ruta.file?

      pkey = OpenSSL::PKey::RSA.new(ruta.read)
      unless pkey.private? && pkey.n.num_bits >= BITS_MINIMOS && pkey.e == EXPONENTE
        Rails.logger.error("pases: clave #{ruta.basename} descartada (no es privada, <#{BITS_MINIMOS} bits o e≠65537)")
        return
      end
      Clave.new(pkey: pkey, desde: desde, hasta: desde.next_month)
    rescue OpenSSL::PKey::PKeyError, Errno::EACCES => e
      Rails.logger.error("pases: no se pudo leer #{ruta.basename}: #{e.class}")
      nil
    end

    def self.inicio_de_mes(ahora) = Time.utc(ahora.utc.year, ahora.utc.month)
  end
end
