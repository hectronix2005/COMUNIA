# Los archivos se sirven solo a quien es de su comunidad (ArchivosProtegidos).
Rails.application.config.to_prepare do
  [
    ActiveStorage::Blobs::RedirectController, ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController
  ].each { _1.include(ArchivosProtegidos) unless _1 < ArchivosProtegidos }
end
