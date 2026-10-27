require "test_helper"

# Recuperar la contraseña: sin correo saliente, la página no promete unas instrucciones que no van a llegar.
class RecuperarClaveTest < ActionDispatch::IntegrationTest
  test "con correo saliente pide el correo; sin él, dice a quién pedir la contraseña" do
    get "/password/new"
    assert_select "form input[type=email]"
    assert_select "#sin-correo", 0

    ActionMailer::Base.perform_deliveries = false
    get "/password/new"
    assert_select "form input[type=email]", 0
    assert_select "#sin-correo", /no envía correos/
  ensure
    ActionMailer::Base.perform_deliveries = true
  end
end
