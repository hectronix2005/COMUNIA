class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :capture_tenant_slug_from_script_name

  def manifest
    render template: "pwa/manifest", formats: [:json]
  end

  def service_worker
    render template: "pwa/service-worker", content_type: "application/javascript"
  end
end
