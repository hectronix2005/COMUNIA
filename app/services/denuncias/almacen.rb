module Denuncias
  # Archivos de evidencia en disco (DENUNCIAS_DIR): originales cifrados y copias públicas.
  # Las claves las genera el servidor; aun así se validan para que ninguna salga de su carpeta,
  # y nunca se sobrescribe una evidencia.
  module Almacen
    class ClaveInvalida < StandardError; end

    CLAVE_VALIDA = %r{\A[a-z]+/[0-9a-f-]+(/[0-9a-f-]+)?\.(bin|jpg|png)\z}

    module_function

    def validar(clave)
      raise ClaveInvalida, "clave de almacén no válida" unless clave.is_a?(String) && CLAVE_VALIDA.match?(clave)
      clave
    end

    def ruta(clave) = Denuncias.dir_evidencia.join(validar(clave))

    def guardar(clave, datos)
      r = ruta(clave)
      FileUtils.mkdir_p(r.dirname, mode: 0o700)
      File.open(r, File::WRONLY | File::CREAT | File::EXCL, 0o600, binmode: true) { _1.write(datos.b) }
    end

    def leer(clave)
      File.binread(ruta(clave))
    rescue Errno::ENOENT
      nil
    end

    def borrar(clave) = FileUtils.rm_f(ruta(clave))
  end
end
