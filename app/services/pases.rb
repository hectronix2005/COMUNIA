# Pases anónimos para DENUNCIAPP: firmas ciegas RSA (RFC 9474,
# RSABSSA-SHA384-PSS-Randomized). El navegador del miembro prepara, ciega y
# desciega; COMUNIA solo firma lo cegado con la clave del mes y publica las
# claves públicas en /pases/claves.json. Contrato v2 con DENUNCIAPP (19-oct-2026).
module Pases
  # Masa mínima para que DENUNCIAPP muestre el sello en público (decisión de Héctor).
  SELLO_MIN_COMUNIDADES = 3
  SELLO_MIN_MIEMBROS = 200

  def self.b64(bytes) = Base64.urlsafe_encode64(bytes, padding: false)

  def self.desde_b64(texto)
    Base64.urlsafe_decode64(texto.to_s)
  rescue ArgumentError
    nil
  end

  # Agregado público: no identifica a nadie. Comunidad = logia con miembros activos.
  def self.sello_publico?
    Rails.cache.fetch("pases/sello_publico", expires_in: 10.minutes) do
      activos = Miembro.activos
      activos.distinct.count(:logia_id) >= SELLO_MIN_COMUNIDADES && activos.count >= SELLO_MIN_MIEMBROS
    end
  end
end
