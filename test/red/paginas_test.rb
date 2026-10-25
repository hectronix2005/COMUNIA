require "test_helper"

# Fase 8: páginas informativas públicas y datos de demostración.
class Red::PaginasTest < ActionDispatch::IntegrationTest
  include RedPrueba

  test "cómo funciona y privacidad abren sin cuenta" do
    get "/red/como-funciona"
    assert_response :ok
    assert_includes response.body, "Ninguna comunidad sabe en qué otras comunidades estás"
    get "/red/privacidad"
    assert_response :ok
    assert_includes response.body, Red::POLITICA_VERSION
    assert_includes response.body, "Suprimir"
  end

  test "los datos de demostración son ficticios, cargan dos veces sin duplicar y respetan el alcance" do
    2.times { capture_io { load Rails.root.join("db/seeds/red_demo.rb") } }
    assert_equal 3, Red::Comunidad.count
    assert User.where(solo_red: true).where.not("email LIKE '%@ejemplo.invalid'").none?
    assert_equal 7, Red::Publicacion.count
    publicas = Red::Publicacion.tablon_para(nil).pluck(:titulo)
    assert_includes publicas, "Clases de guitarra para principiantes"
    assert_not_includes publicas, "Arriendo habitación amoblada", "solo para la universidad elegida"
  end
end
