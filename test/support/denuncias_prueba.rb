# Utilidades de las pruebas de DENUNCIAPP (traducción de tests/utilidades.ts del repo de referencia).
module DenunciasPrueba
  HOST = "denuncias.test".freeze
  ORIGEN = "http://#{HOST}".freeze

  def self.seg(marcador, cuerpo) = [0xFF, marcador, (cuerpo.size + 2) >> 8, (cuerpo.size + 2) & 255, *cuerpo]
  def self.ascii(s) = s.bytes

  # JPEG mínimo con APP0 (se conserva), APP1/EXIF con un «GPS» y un comentario (se retiran).
  def self.jpeg_con_exif
    [0xFF, 0xD8,
     *seg(0xE0, [*ascii("JFIF"), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
     *seg(0xE1, [*ascii("Exif"), 0, 0, *ascii("GPS 4.6097,-74.0817")]),
     *seg(0xFE, ascii("comentario del telefono")),
     *seg(0xDB, [0, 1, 2]),
     *seg(0xDA, [1, 2]),
     0x11, 0x22, 0x33, 0xFF, 0xD9].pack("C*")
  end

  def contiene(datos, texto) = datos.to_s.b.include?(texto.b)

  # Entorno aislado: host del módulo, carpeta de evidencia temporal, captcha y límites limpios,
  # y un almacén de claves de pases propio (con o sin claves).
  def preparar_denuncias(captcha: true, claves_json: nil)
    @env_antes = ENV.to_h.slice("DENUNCIAPP_URL", "DENUNCIAS_DIR")
    @dir_evidencia = Dir.mktmpdir("denuncias")
    ENV["DENUNCIAPP_URL"] = ORIGEN
    ENV["DENUNCIAS_DIR"] = @dir_evidencia
    Denuncias::Captcha.verificador = ->(_token) { captcha }
    Denuncias::Limitador.global.reiniciar!
    json = claves_json || { "claves" => [], "sello_publico" => false }
    Denuncias::Pases.almacen = Denuncias::Pases::Almacen.new(fuente: -> { json })
  end

  def limpiar_denuncias
    @env_antes&.each { |k, v| ENV[k] = v }
    Denuncias::Captcha.verificador = nil
    Denuncias::Pases.almacen = nil
    FileUtils.remove_entry(@dir_evidencia) if @dir_evidencia && File.exist?(@dir_evidencia)
  end

  def foto(bytes = DenunciasPrueba.jpeg_con_exif, nombre = "f.jpg", tipo = "image/jpeg")
    archivo = Tempfile.new([nombre, File.extname(nombre)], binmode: true)
    archivo.write(bytes)
    archivo.rewind
    Rack::Test::UploadedFile.new(archivo.path, tipo, true, original_filename: nombre)
  end

  def formulario(campos = {}, fotos: [DenunciasPrueba.jpeg_con_exif], hashes: nil)
    { categoria: "hurto_rina_vandalismo", titulo: "Robo en la esquina", descripcion: "Dos personas robaron un celular.",
      localidad: "Chapinero", lugar: "Calle 60 con 7", acepto_terminos: "si" }.merge(campos)
      .merge(fotos: fotos.map { foto(_1) }, hashes: hashes || fotos.map { Denuncias::Cripto.sha256_hex(_1) })
  end

  # publicar(titulo: "x") o publicar({ titulo: "x" }, ip: "1.2.3.4"): los campos sueltos van al formulario.
  def publicar(campos = {}, ip: "9.9.9.9", headers: {}, fotos: [DenunciasPrueba.jpeg_con_exif], hashes: nil, **resto)
    host! HOST
    post "/api/reportes", params: formulario(campos.merge(resto), fotos: fotos, hashes: hashes),
                          headers: headers, env: { "REMOTE_ADDR" => ip }
    response
  end

  def muro
    host! HOST
    get "/api/reportes"
    JSON.parse(response.body)
  end
end
