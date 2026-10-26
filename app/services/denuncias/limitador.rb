module Denuncias
  # Límite de intentos SOLO en memoria. La IP nunca se guarda ni se registra: pasa por un HMAC con
  # una clave aleatoria que se descarta en cada ventana, junto con todos los contadores.
  # (rack-attack y rate_limit guardan la IP en claro en Solid Cache, que es una tabla de Postgres.)
  class Limitador
    MAXIMOS = { reporte: 5, retiro: 10, retiro_reporte: 1 }.freeze

    def self.global = @global ||= new(MAXIMOS)

    def initialize(maximos, ventana: 3600, reloj: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @maximos = maximos
      @ventana = ventana
      @reloj = reloj
      @mutex = Mutex.new
      @clave = nil
    end

    def permitir(accion, ip)
      maximo = @maximos.fetch(accion.to_sym)
      @mutex.synchronize do
        rotar_si_toca
        llave = "#{accion}:#{OpenSSL::HMAC.digest('SHA256', @clave, ip.to_s).byteslice(0, 12).unpack1('H*')}"
        usados = @cuentas[llave].to_i
        return false if usados >= maximo
        @cuentas[llave] = usados + 1
        true
      end
    end

    def reiniciar! = @mutex.synchronize { @clave = nil }

    private

    def rotar_si_toca
      return if @clave && @reloj.call - @inicio < @ventana
      @clave = SecureRandom.random_bytes(32)
      @inicio = @reloj.call
      @cuentas = {}
    end
  end
end
