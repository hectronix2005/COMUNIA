require "test_helper"

# Traspaso, sección 5, pruebas 19–32 (tests/nucleo.test.ts de DENUNCIAPP).
class Denuncias::NucleoTest < ActiveSupport::TestCase
  include DenunciasPrueba

  C = Denuncias::Cripto
  X = Denuncias::Exif

  test "19. cifra y descifra; el texto cifrado no contiene el original" do
    clave = SecureRandom.random_bytes(32)
    cifrado = C.cifrar("evidencia secreta", clave)
    assert_not contiene(cifrado, "evidencia")
    assert_equal "evidencia secreta", C.descifrar(cifrado, clave)
    otra = SecureRandom.random_bytes(32)
    assert_raises(OpenSSL::Cipher::CipherError) { C.descifrar(cifrado, otra) }
  end

  test "20. rechaza claves que no son de 32 bytes" do
    assert_raises(C::ClaveInvalida) { C.importar_clave(Base64.strict_encode64("\0" * 16)) }
    assert_raises(C::ClaveInvalida) { C.importar_clave("no es base64!") }
    assert_equal 32, C.importar_clave(Base64.strict_encode64("\1" * 32)).bytesize
  end

  test "22. redondea la hora hacia abajo" do
    assert_equal Time.utc(2026, 10, 19, 18), C.hora_redondeada(Time.utc(2026, 10, 19, 18, 47, 12.345))
    # El día público es el de Bogotá: las 20:00 de Bogotá ya son «mañana» en UTC.
    assert_equal "2026-10-19", C.fecha_bogota(Time.utc(2026, 10, 20, 1))
  end

  test "23. quita EXIF/GPS y comentarios de un JPEG y conserva la imagen" do
    original = DenunciasPrueba.jpeg_con_exif
    mime, limpia, metadatos = X.limpiar(original)
    assert_equal "image/jpeg", mime
    assert_not contiene(limpia, "GPS")
    assert_not contiene(limpia, "comentario")
    assert contiene(limpia, "JFIF")
    assert contiene(metadatos, "GPS 4.6097")
    assert_equal original.byteslice(-5..), limpia.byteslice(-5..) # datos de imagen intactos
  end

  test "24. conserva solo la orientación del EXIF, sin GPS ni modelo" do
    tiff = [0x49, 0x49, 0x2A, 0, 8, 0, 0, 0, 1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0]
    cuerpo = "Exif\0\0".bytes + tiff + "GPS 4.6 iPhone".bytes
    jpeg = ([0xFF, 0xD8, 0xFF, 0xE1, (cuerpo.size + 2) >> 8, (cuerpo.size + 2) & 255] + cuerpo + [0xFF, 0xDA, 0, 4, 1, 2, 0x11, 0xFF, 0xD9]).pack("C*")
    _, limpia, = X.limpiar(jpeg)
    assert_not contiene(limpia, "GPS")
    assert_not contiene(limpia, "iPhone")
    assert_equal [0xFF, 0xE1], limpia.byteslice(2, 2).bytes
    assert_equal 6, X.leer_orientacion(limpia.byteslice(2..))
  end

  test "25. quita tEXt de un PNG" do
    chunk = ->(tipo, datos) { [datos.size].pack("N") + tipo + datos.pack("C*") + "\0\0\0\0" }
    png = "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [1] * 13) + chunk.("tEXt", "Location\0Bogota".bytes) +
          chunk.("IDAT", [9, 9]) + chunk.("IEND", [])
    _, limpia, metadatos = X.limpiar(png)
    assert_not contiene(limpia, "Bogota")
    assert contiene(metadatos, "Bogota")
    assert contiene(limpia, "IDAT")
  end

  test "26. rechaza formatos que no son JPEG ni PNG" do
    assert_raises(X::FormatoNoAdmitido) { X.limpiar("<svg onload=alert(1)>") }
  end

  test "27. encadena eventos y detecta una alteración" do
    e1 = Denuncias::Custodia.registrar("r1", "evidencia_recibida", { sha256: "abc" })
    e2 = Denuncias::Custodia.registrar("r1", "reporte_publicado")
    assert_equal Denuncias::Custodia::GENESIS, e1.hash_prev
    assert_equal e1.hash_evento, e2.hash_prev
    eventos = Denuncias::EventoCustodia.where(reporte_id: "r1").order(:n).to_a
    assert_equal({ valida: true, eventos: 2 }, Denuncias::Custodia.verificar(eventos))

    alterado = eventos.first.dup.tap { _1.detalle_json = '{"sha256":"otro"}' }
    assert_equal({ valida: false, roto_en: 0 }, Denuncias::Custodia.verificar([alterado, eventos.last]))
  end

  test "28. la base de datos no deja editar ni borrar eventos" do
    Denuncias::Custodia.registrar("r1", "x")
    c = ActiveRecord::Base.connection
    %w[UPDATE\ denuncias_eventos_custodia\ SET\ tipo\ =\ 'y' DELETE\ FROM\ denuncias_eventos_custodia TRUNCATE\ denuncias_eventos_custodia].each do |sql|
      error = assert_raises(ActiveRecord::StatementInvalid) { c.transaction(requires_new: true) { c.execute(sql) } }
      assert_match(/solo de inserción/, error.message)
    end
  end

  test "29. cuenta por IP en memoria y se reinicia al rotar la ventana" do
    ahora = 0
    l = Denuncias::Limitador.new({ reporte: 2 }, ventana: 1, reloj: -> { ahora })
    assert l.permitir(:reporte, "1.1.1.1")
    assert l.permitir(:reporte, "1.1.1.1")
    assert_not l.permitir(:reporte, "1.1.1.1")
    assert l.permitir(:reporte, "2.2.2.2")
    ahora = 1.001
    assert l.permitir(:reporte, "1.1.1.1")
    # La IP no queda en memoria: solo un HMAC con una clave que se descarta.
    assert_not_includes l.instance_variable_get(:@cuentas).keys.join, "1.1.1.1"
  end

  test "30. el almacén no acepta claves que salgan de su carpeta" do
    assert_raises(Denuncias::Almacen::ClaveInvalida) { Denuncias::Almacen.validar("../../etc/passwd") }
    assert_raises(Denuncias::Almacen::ClaveInvalida) { Denuncias::Almacen.validar("publicas/../x.jpg") }
    assert_equal "publicas/0a1b-2c.jpg", Denuncias::Almacen.validar("publicas/0a1b-2c.jpg")
  end

  test "31. oculta cédulas y teléfonos con o sin separadores" do
    texto, ocultos = Denuncias::Filtro.ocultar("Es Pedro, CC 1.020.304.050, cel 310 555 1234 o +57 601-234-5678")
    assert_equal "Es Pedro, CC [dato oculto], cel [dato oculto] o [dato oculto]", texto
    assert_equal 3, ocultos
  end

  test "32. no toca direcciones, placas, años ni montos" do
    t = "Calle 145 # 91-20, placa ABC123, en 2026, le robaron $1.500.000"
    assert_equal [t, 0], Denuncias::Filtro.ocultar(t)
  end
end
