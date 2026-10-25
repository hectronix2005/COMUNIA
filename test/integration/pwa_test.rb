require "test_helper"

# Sin manifiesto legible no se instala la app, y sin service worker no hay notificaciones push.
class PwaTest < ActionDispatch::IntegrationTest
  test "el manifiesto es JSON válido, sin comillas escapadas para HTML" do
    get "/manifest"
    assert_response :ok
    datos = JSON.parse(response.body)
    assert_equal "/", datos["scope"]
    assert_not_includes response.body, "&quot;"
  end

  test "el service worker se sirve como JavaScript, también bajo el prefijo de un tenant" do
    ["/service-worker", "/t/demo/service-worker"].each do |ruta|
      get ruta
      assert_response :ok, ruta
      assert_equal "application/javascript", response.media_type
      assert_includes response.body, "addEventListener(\"push\""
    end
  end
end
