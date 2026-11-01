require "test_helper"

# Al compartir un enlace de COMUNIA (WhatsApp, Telegram…) sale el logo: og:image con la URL del dominio
# configurado, nunca la del Host que mande la petición.
class VistaPreviaTest < ActionDispatch::IntegrationTest
  test "la portada, el login de una comunidad y la red llevan la vista previa con el logo" do
    logia = Logia.create!(nombre: "Egresados Prueba", slug: "prev-#{SecureRandom.hex(3)}", codigo: "PV#{rand(10_000)}")

    { "/" => "COMUNIA", "/t/#{logia.slug}/login" => "Egresados Prueba", "/red" => "Red COMUNIA" }.each do |ruta, titulo|
      get ruta, headers: { "Host" => "otro-host.example" }
      assert_response :success, ruta
      assert_select "meta[property='og:image'][content=?]", "http://example.com/og-image.jpg?v=1", { count: 1 }, ruta
      assert_select "meta[property='og:title'][content*='#{titulo}']", 1, ruta
      assert_select "meta[name='twitter:card'][content='summary_large_image']", 1, ruta
    end
    assert Rails.public_path.join("og-image.jpg").exist?
  end

  test "el muro de denuncias también lleva el logo, sin datos de ninguna denuncia" do
    get "/denuncias", headers: { "Host" => "otro-host.example" }
    assert_response :success
    assert_select "meta[property='og:image'][content=?]", "http://example.com/og-image.jpg?v=1", 1
    assert_select "meta[property='og:title'][content='Muro · Denuncias']", 1
    assert_select "meta[property='og:description'][content*='Piloto en Bogotá']", 1
  end
end
