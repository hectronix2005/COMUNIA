class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :capture_tenant_slug_from_script_name
  # El service worker es estático (nada del usuario): sin esto, Rails lo trata como JavaScript pedido
  # desde otro sitio y responde 422, el navegador no lo registra y no hay notificaciones push.
  skip_forgery_protection only: :service_worker

  def manifest
    render template: "pwa/manifest", formats: [:json]
  end

  def service_worker
    render template: "pwa/service-worker", formats: [:js], content_type: "application/javascript"
  end
end
