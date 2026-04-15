Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.media_src   :self, :https, :data, :blob
    policy.object_src  :none
    policy.frame_ancestors :self
    policy.base_uri    :self
    policy.form_action :self
    policy.script_src  :self, :https
    # Bootstrap + estilos inline en vistas legacy → permitidos por ahora.
    policy.style_src   :self, :https, :unsafe_inline
    # WebSocket / Action Cable.
    policy.connect_src :self, :https, :wss
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Modo report-only para no romper la app: el navegador reporta en
  # consola pero no bloquea. Cambiar a false tras auditar inline scripts.
  config.content_security_policy_report_only = true
end

# Permissions-Policy: bloquea APIs del navegador que la app no usa.
Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "geolocation=(), camera=(), microphone=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()"
)
