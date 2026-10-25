# Rate limiting & brute-force protection.
# Usa el cache memstore por defecto (Rails.cache); si en el futuro se
# habilita Solid Cache o Redis, Rack::Attack lo aprovecha automáticamente.

class Rack::Attack
  ### Allow ###
  # Allowlist health checks y assets.
  Rack::Attack.safelist("allow-health") do |req|
    req.path.start_with?("/up", "/assets/")
  end

  # El host de DENUNCIAPP no pasa por aquí: rack-attack guarda la IP en claro en Rails.cache (Solid
  # Cache = tabla de Postgres, que viaja en las copias). Allí limita Denuncias::Limitador, en memoria.
  Rack::Attack.safelist("denunciapp") do |req|
    req.env["denuncias.host"]
  end

  ### Throttles ###

  # 1) POST /login (también /t/:slug/login). Máx 8 intentos / 5 min por IP.
  throttle("logins/ip", limit: 8, period: 5.minutes) do |req|
    if req.post? && req.path =~ %r{(?:^|/)(login|users/sign_in|red/entrar)\z}
      req.ip
    end
  end

  # 2) POST /login por email — máx 6 intentos por email / 5 min.
  throttle("logins/email", limit: 6, period: 5.minutes) do |req|
    if req.post? && req.path =~ %r{(?:^|/)(login|users/sign_in|red/entrar)\z}
      email = req.params.dig("user", "email").to_s.downcase.strip
      email.presence
    end
  end

  # 3) POST /password (recuperación) — máx 5 / hora por IP.
  throttle("password-resets/ip", limit: 5, period: 1.hour) do |req|
    if req.post? && req.path.end_with?("/password")
      req.ip
    end
  end

  # 4) POST /chat — máx 60 mensajes / minuto por usuario para mitigar floods.
  throttle("chat/ip", limit: 60, period: 1.minute) do |req|
    if req.post? && req.path.end_with?("/chat")
      req.ip
    end
  end

  # Red de comunidades: registro, contacto sin cuenta y reportes (formularios públicos con captcha).
  throttle("red/registro/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/red/registro"
  end
  throttle("red/publico/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/red/(publicaciones/[^/]+/contactar|reportar)\z})
  end
  # Escrituras con cuenta en la red (mensajes, publicaciones, solicitudes): contra ráfagas.
  throttle("red/escrituras/ip", limit: 60, period: 10.minutes) do |req|
    req.ip if !req.get? && !req.head? && req.path.start_with?("/red/") && req.path != "/red/entrar"
  end
  # La búsqueda sin cuenta: contra el raspado del directorio.
  throttle("red/buscar/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/red/buscar")
  end

  # 5) Ráfaga global por IP para mitigar scraping/DoS.
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/up", "/assets/")
  end

  ### Response personalizada ###
  # Recibe un Rack::Attack::Request, no el env: con `env[...]` el 429 salía como 500.
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      ["Demasiadas peticiones. Reintenta en #{retry_after} segundos.\n"]
    ]
  end
end
