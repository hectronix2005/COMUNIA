module Denuncias
  # Separa los metadatos (EXIF, GPS, XMP, ICC, comentarios) de una foto antes de publicarla.
  # Los metadatos retirados se guardan cifrados como evidencia; la copia pública va limpia.
  # El formato se detecta por los bytes mágicos, no por el Content-Type: solo JPEG y PNG.
  module Exif
    class FormatoNoAdmitido < StandardError; end

    FIRMA_PNG = "\x89PNG\r\n\x1A\n".b.freeze
    CHUNKS_PNG_RETIRADOS = %w[eXIf tEXt zTXt iTXt tIME].freeze

    module_function

    def detectar(b)
      b = b.b
      return "image/jpeg" if b.bytesize > 3 && b.getbyte(0) == 0xFF && b.getbyte(1) == 0xD8 && b.getbyte(2) == 0xFF
      return "image/png" if b.bytesize > 8 && b.start_with?(FIRMA_PNG)
      nil
    end

    # → [mime, limpia, metadatos]
    def limpiar(b)
      b = b.b
      case detectar(b)
      when "image/jpeg" then ["image/jpeg", *limpiar_jpeg(b)]
      when "image/png" then ["image/png", *limpiar_png(b)]
      else raise FormatoNoAdmitido, "formato no admitido"
      end
    end

    # Etiqueta Orientation (0x0112) del IFD0 de un segmento APP1/EXIF: 1..8 o nil.
    def leer_orientacion(seg)
      seg = seg.b
      tiff = 10 # FF E1 LL LL 'Exif\0\0'
      return nil if seg.bytesize < tiff + 8 || seg.byteslice(4, 4) != "Exif"

      t = seg.byteslice(tiff..)
      le = t.byteslice(0, 2) == "II"
      u16 = ->(o) { (s = t.byteslice(o, 2)) && s.bytesize == 2 ? s.unpack1(le ? "v" : "n") : raise(IndexError) }
      u32 = ->(o) { (s = t.byteslice(o, 4)) && s.bytesize == 4 ? s.unpack1(le ? "V" : "N") : raise(IndexError) }
      ifd = u32.(4)
      u16.(ifd).times do |k|
        e = ifd + 2 + k * 12
        next unless u16.(e) == 0x0112
        v = u16.(e + 8)
        return v.between?(1, 8) ? v : nil
      end
      nil
    rescue IndexError
      nil
    end

    # APP1 mínimo con solo la orientación: la foto no sale girada y no se filtra nada más.
    def exif_solo_orientacion(o)
      cuerpo = "Exif\0\0".b + [0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8, 0, 1, 0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, o, 0, 0, 0, 0, 0, 0].pack("C*")
      [0xFF, 0xE1].pack("C*") + [cuerpo.bytesize + 2].pack("n") + cuerpo
    end

    def limpiar_jpeg(b)
      conservar = [b.byteslice(0, 2)]
      retirar = []
      orientacion = nil
      i = 2
      while i < b.bytesize
        raise FormatoNoAdmitido, "JPEG corrupto" unless b.getbyte(i) == 0xFF
        marcador = b.getbyte(i + 1)
        raise FormatoNoAdmitido, "JPEG corrupto" if marcador.nil?
        if marcador == 0xFF then i += 1; next end # relleno
        if marcador == 0xDA then conservar << b.byteslice(i..); break end # SOS: el resto es imagen
        if marcador == 0xD9 || marcador.between?(0xD0, 0xD7) || marcador == 0x01
          conservar << b.byteslice(i, 2)
          i += 2
          next
        end
        raise FormatoNoAdmitido, "JPEG corrupto" if i + 4 > b.bytesize
        largo = b.byteslice(i + 2, 2).unpack1("n")
        seg = b.byteslice(i, 2 + largo)
        raise FormatoNoAdmitido, "JPEG corrupto" unless seg.bytesize == largo + 2
        # APP1..APP15 (EXIF, XMP, IPTC, ICC…) y COM se retiran; APP0 (JFIF) se conserva.
        metadato = marcador.between?(0xE1, 0xEF) || marcador == 0xFE
        orientacion ||= leer_orientacion(seg) if marcador == 0xE1
        (metadato ? retirar : conservar) << seg
        i += 2 + largo
      end
      if orientacion && orientacion != 1
        tras = conservar[1]&.getbyte(1) == 0xE0 ? 2 : 1
        conservar.insert(tras, exif_solo_orientacion(orientacion))
      end
      [conservar.join.b, retirar.join.b]
    end

    def limpiar_png(b)
      conservar = [b.byteslice(0, 8)]
      retirar = []
      i = 8
      while i + 12 <= b.bytesize
        largo = b.byteslice(i, 4).unpack1("N")
        tipo = b.byteslice(i + 4, 4)
        chunk = b.byteslice(i, 12 + largo)
        raise FormatoNoAdmitido, "PNG corrupto" unless chunk.bytesize == largo + 12
        (CHUNKS_PNG_RETIRADOS.include?(tipo) ? retirar : conservar) << chunk
        i += 12 + largo
        break if tipo == "IEND"
      end
      [conservar.join.b, retirar.join.b]
    end
  end
end
