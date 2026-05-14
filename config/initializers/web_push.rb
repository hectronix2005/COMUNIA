Rails.application.config.x.vapid = {
  public_key:  ENV.fetch("VAPID_PUBLIC_KEY", ""),
  private_key: ENV.fetch("VAPID_PRIVATE_KEY", ""),
  subject:     ENV.fetch("VAPID_SUBJECT", "mailto:admin@comunia.app")
}
