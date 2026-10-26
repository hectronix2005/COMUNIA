require "test_helper"

# «Activa los avisos en este teléfono»: la tarjeta del panel sale a quien no recibe avisos en ningún dispositivo y
# desaparece en cuanto se suscribe uno. Qué ofrecer según el navegador lo decide activar_avisos_controller.
class ActivarAvisosTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @mercedes = Logia.create!(nombre: "Mercedes", slug: "mercedes-#{SecureRandom.hex(3)}", codigo: "L#{SecureRandom.hex(3).upcase}")
    @socio = User.create!(nombre: "Sara", apellido: "Prueba", email: "sara_#{SecureRandom.hex(3)}@correo.co",
                          password: "password123", logia: @mercedes, rol_ref: @rol_miembro)
    Miembro.create!(user: @socio, logia: @mercedes, numero_miembro: "N#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
  end

  test "sale a quien no recibe avisos y desaparece al suscribirse un dispositivo" do
    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_response :ok
    assert_includes response.body, 'data-controller="activar-avisos"'
    assert_includes response.body, "Activa los avisos en este teléfono"

    post "/push_subscriptions", params: { endpoint: "https://push.example.com/abc", p256dh: "clave", auth: "secreto" }, as: :json
    assert_equal 1, @socio.push_subscriptions.count
    get "/t/#{@mercedes.slug}/dashboard"
    assert_not_includes response.body, "Activa los avisos en este teléfono"
  end
end
