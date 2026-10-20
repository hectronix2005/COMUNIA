# Frontera del host de DENUNCIAPP (va la primera de la pila).
# - En ese host solo existen las rutas del módulo: el resto da 404, así que ni el login de
#   COMUNIA ni ninguna otra página suya se puede abrir allí.
# - En ese host no se escribe nada en el log de Rails: ni «Started … for <IP> at <hora>», ni
#   parámetros, ni SQL. Solo errores, que no llevan IP.
# - Marca la petición para que rack-attack no la cuente (guardaría la IP en Solid Cache, que
#   es una tabla de Postgres y viaja en las copias).
class DenunciasFrontera
  RUTAS = %r{\A/(?:|nuevo|cuenta|entrar|terminos|api/.+|media/publicas/[^/]+|estaticos/[^/]+|cuenta/auth(?:/.*)?)\z}

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless Denuncias.host?(env["HTTP_HOST"])

    path = env["PATH_INFO"].to_s
    return [404, { "content-type" => "text/plain" }, ["No encontrado\n"]] unless RUTAS.match?(path)

    env["denuncias.host"] = true
    Rails.logger.silence(Logger::ERROR) { @app.call(env) }
  end
end
