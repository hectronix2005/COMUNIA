class TenantPathPrefix
  MATCH = %r{\A/t/([a-z0-9][a-z0-9\-_]*)(/.*)\z}.freeze
  # La red no tiene tenant: si sus URLs llevaran /t/<slug>, un enlace compartido delataría la
  # organización de quien lo copió. Se manda a la misma ruta sin prefijo.
  RED = %r{\A/red(/|\z)}.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    if (m = MATCH.match(path))
      slug = m[1]
      rest = m[2]
      return sin_prefijo(env, rest) if RED.match?(rest)
      env["SCRIPT_NAME"] = "#{env['SCRIPT_NAME']}/t/#{slug}"
      env["PATH_INFO"] = rest
    end
    @app.call(env)
  end

  private

  def sin_prefijo(env, rest)
    return [404, { "content-type" => "text/plain" }, ["Not Found"]] unless env["REQUEST_METHOD"].in?(%w[GET HEAD])
    destino = "#{env['SCRIPT_NAME']}#{rest}"
    destino += "?#{env['QUERY_STRING']}" if env["QUERY_STRING"].present?
    [301, { "location" => destino, "content-type" => "text/plain" }, []]
  end
end
