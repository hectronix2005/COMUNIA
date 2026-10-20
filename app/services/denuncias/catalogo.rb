module Denuncias
  # Listas blancas: nada que venga de la petición se usa fuera de estas listas.
  module Catalogo
    CATEGORIAS = {
      "mal_parqueo" => "Mal parqueo",
      "hurto_rina_vandalismo" => "Hurto, riña o vandalismo",
      "ubicacion_buscado" => "Ubicación de un buscado",
      "microtrafico_extorsion" => "Microtráfico o extorsión"
    }.freeze

    LOCALIDADES = [
      "Usaquén", "Chapinero", "Santa Fe", "San Cristóbal", "Usme", "Tunjuelito", "Bosa", "Kennedy",
      "Fontibón", "Engativá", "Suba", "Barrios Unidos", "Teusaquillo", "Los Mártires", "Antonio Nariño",
      "Puente Aranda", "La Candelaria", "Rafael Uribe Uribe", "Ciudad Bolívar", "Sumapaz"
    ].freeze

    MAX_FOTOS = 4
    MAX_BYTES_FOTO = 10 * 1024 * 1024

    def self.categoria?(v) = v.is_a?(String) && CATEGORIAS.key?(v)
    def self.localidad?(v) = v.is_a?(String) && LOCALIDADES.include?(v)
  end
end
