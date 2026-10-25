require "test_helper"

# Pedir el cambio de contraseña no debe delatar si un correo tiene cuenta (en la red, eso diría que
# alguien está en COMUNIA), ni romper la página si el servidor de correo falla.
class RecuperarClaveTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "con o sin cuenta, la respuesta es la misma y el correo sale en segundo plano" do
    logia = Logia.create!(nombre: "Logia Clave", slug: "clave-#{SecureRandom.hex(3)}", codigo: "CL#{rand(10_000)}")
    user = User.create!(nombre: "Ana", apellido: "Prueba", email: "ana_#{SecureRandom.hex(3)}@correo.co", password: "password123", logia: logia)

    respuestas = [user.email, "nadie_#{SecureRandom.hex(3)}@correo.co"].map do |email|
      post "/password", params: { user: { email: email } }
      [response.status, response.location, flash[:notice]]
    end
    assert_equal respuestas.first, respuestas.last
    assert_equal 1, enqueued_jobs.count { _1["job_class"] == "ActionMailer::MailDeliveryJob" }
  end
end
