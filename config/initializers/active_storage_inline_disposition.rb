# Active Storage's RedirectController passes params[:disposition] (nil when not specified)
# to blob.url, which overrides the :inline default and causes the disk service to serve
# images with Content-Disposition: attachment — breaking <img> rendering for SVG files.
# This patch ensures inline is used when no disposition is explicitly requested.
Rails.application.config.to_prepare do
  ActiveStorage::Blobs::RedirectController.prepend(Module.new do
    def show
      expires_in ActiveStorage.service_urls_expire_in
      redirect_to @blob.url(disposition: params[:disposition].presence || :inline), allow_other_host: true
    end
  end)
end
