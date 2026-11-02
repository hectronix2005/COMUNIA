module Noticias
  # Busca en Google Noticias (RSS, sin clave) en español de Colombia. Devuelve titular, medio, fecha y enlace:
  # nunca el texto del artículo. La frase va codificada en la URL; el servidor es siempre news.google.com.
  module GoogleNoticias
    BASE = "https://news.google.com/rss/search".freeze
    POR_BUSQUEDA = 10

    # En pruebas se sustituye con Noticias::GoogleNoticias.descargador = ->(url) { xml }
    mattr_accessor :descargador

    module_function

    def url(frase)
      "#{BASE}?#{URI.encode_www_form(q: "#{frase} when:#{Noticia::DIAS}d", hl: 'es-419', gl: 'CO', ceid: 'CO:es-419')}"
    end

    def buscar(frase)
      leer(descargar(url(frase))).first(POR_BUSQUEDA)
    end

    def leer(xml)
      Nokogiri::XML(xml.to_s).xpath("//item").filter_map do |item|
        enlace = item.at_xpath("link")&.text.to_s.strip
        medio = item.at_xpath("source")&.text.to_s.strip.presence
        titulo = item.at_xpath("title")&.text.to_s.strip
        titulo = titulo.delete_suffix(" - #{medio}") if medio
        fecha = fecha(item.at_xpath("pubDate")&.text)
        next unless enlace.start_with?("https://") && titulo.present? && fecha

        { titulo: titulo.truncate(300), medio: medio&.truncate(120), url: enlace, publicada_en: fecha }
      end
    end

    def fecha(texto)
      Time.zone.parse(texto.to_s)
    rescue ArgumentError
      nil
    end

    def descargar(url)
      return descargador.call(url) if descargador

      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        respuesta = http.get(uri.request_uri, "User-Agent" => "COMUNIA/1.0")
        respuesta.is_a?(Net::HTTPSuccess) ? respuesta.body : ""
      end
    end
  end
end
