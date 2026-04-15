class TenantPathPrefix
  MATCH = %r{\A/t/([a-z0-9][a-z0-9\-_]*)(/.*)\z}.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    if (m = MATCH.match(path))
      slug = m[1]
      rest = m[2]
      env["SCRIPT_NAME"] = "#{env['SCRIPT_NAME']}/t/#{slug}"
      env["PATH_INFO"] = rest
    end
    @app.call(env)
  end
end
