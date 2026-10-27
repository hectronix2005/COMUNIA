require "test_helper"

# Producción solo trae libvips; si el procesador no coincide, las imágenes
# subidas se guardan sin ancho ni alto.
class ImagenAnalisisTest < ActiveSupport::TestCase
  test "una imagen subida guarda su ancho y su alto" do
    begin
      require "ruby-vips"
    rescue LoadError
      skip "libvips no está instalado en esta máquina"
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("imagen_40x30.png").open, filename: "imagen.png", content_type: "image/png"
    )
    blob.analyze

    assert_equal :vips, Rails.application.config.active_storage.variant_processor
    assert_equal 40, blob.metadata[:width]
    assert_equal 30, blob.metadata[:height]
  end
end
