# Rate limiting & brute-force protection.
# Usa el cache memstore por defecto (Rails.cache); si en el futuro se
# habilita Solid Cache o Redis, Rack::Attack lo aprovecha automáticamente.

class Rack::Attack
  ### Allow ###
  # Allowlist health checks (Heroku) y assets.
  Rack::Attack.safelist("allow-health") do |req|
    req.path.start_with?("/up", "/assets/")
  end

  ### Throttles ###

  # 1) POST /login (también /t/:slug/login). Máx 8 intentos / 5 min por IP.
  throttle("logins/ip", limit: 8, period: 5.minutes) do |req|
    if req.post? && req.path =~ %r{(?:^|/)(login|users/sign_in)\z}
      req.ip
    end
  end

  # 2) POST /login por email — máx 6 intentos por email / 5 min.
  throttle("logins/email", limit: 6, period: 5.minutes) do |req|
    if req.post? && req.path =~ %r{(?:^|/)(login|users/sign_in)\z}
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

  # 5) Ráfaga global por IP para mitigar scraping/DoS.
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/up", "/assets/")
  end

  ### Response personalizada ###
  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      ["Demasiadas peticiones. Reintenta en #{retry_after} segundos.\n"]
    ]
  end
end
