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

  # Entorno aislado: carpeta de evidencia temporal, captcha y límites limpios.
  def preparar_denuncias(captcha: true)
    @dir_antes = ENV["DENUNCIAS_DIR"]
    @dir_evidencia = Dir.mktmpdir("denuncias")
    ENV["DENUNCIAS_DIR"] = @dir_evidencia
    Denuncias::Captcha.verificador = ->(_token) { captcha }
    Denuncias::Limitador.global.reiniciar!
  end

  def limpiar_denuncias
    ENV["DENUNCIAS_DIR"] = @dir_antes
    Denuncias::Captcha.verificador = nil
    FileUtils.remove_entry(@dir_evidencia) if @dir_evidencia && File.exist?(@dir_evidencia)
  end

  # Usuario de COMUNIA con ficha en una comunidad (activa salvo que se diga otro estado).
  def vecino(nombre = "Ana", estado: :activo, rol: "miembro")
    rol_ref = Rol.find_or_create_by!(codigo: rol) { _1.nombre = rol.humanize }
    logia = Logia.create!(nombre: "Barrio #{SecureRandom.hex(3)}", slug: "barrio-#{SecureRandom.hex(4)}",
                          codigo: "L#{SecureRandom.hex(3).upcase}")
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(4)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: estado, estado_desde: (Date.current unless estado == :activo))
    user
  end

  def foto(bytes = DenunciasPrueba.jpeg_con_exif, nombre = "f.jpg", tipo = "image/jpeg")
    archivo = Tempfile.new([nombre, File.extname(nombre)], binmode: true)
    archivo.write(bytes)
    archivo.rewind
    Rack::Test::UploadedFile.new(archivo.path, tipo, true, original_filename: nombre)
  end

  # Como el navegador: el file_field múltiple manda antes un valor vacío.
  def formulario(campos = {}, fotos: [DenunciasPrueba.jpeg_con_exif], hashes: nil)
    { categoria: "hurto_rina_vandalismo", titulo: "Robo en la esquina", descripcion: "Dos personas robaron un celular.",
      localidad: "Chapinero", lugar: "Calle 60 con 7", acepto_terminos: "si" }.merge(campos)
      .merge(fotos: ["", *fotos.map { foto(_1) }], hashes: hashes || fotos.map { Denuncias::Cripto.sha256_hex(_1) })
  end

  # Publica con la sesión que haya (publicar(titulo: "x")); devuelve la última denuncia creada, o nil.
  def publicar(campos = {}, fotos: [DenunciasPrueba.jpeg_con_exif], hashes: nil, **resto)
    antes = Denuncias::Reporte.maximum(:n).to_i
    post "/denuncias", params: formulario(campos.merge(resto), fotos: fotos, hashes: hashes)
    Denuncias::Reporte.where("n > ?", antes).order(:n).last
  end
end
