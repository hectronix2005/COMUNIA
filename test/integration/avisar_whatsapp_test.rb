require "test_helper"

# Avisar por WhatsApp: quien gestiona la reunión abre WhatsApp con la convocatoria escrita (o, después, con que ya
# está el acta) para pegarla en el grupo. El mensaje no lleva el orden del día ni el acta: solo el enlace a COMUNIA.
class AvisarWhatsappTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @admin = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio = persona("Sara", @suv)
    inicio = 2.days.from_now.change(hour: 19)
    @reunion = Reunion.create!(logia: @suv, user: @admin, titulo: "Ruta al páramo", inicio: inicio, fin: inicio + 2.hours,
                               lugar: "Parque de la 93", orden_del_dia: "1. Cuotas atrasadas de Simón")
    @base = "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"
  end

  test "quien gestiona avisa de la convocatoria con fecha, lugar y enlace, sin el orden del día" do
    sign_in @admin
    get @base
    texto = mensaje_whatsapp
    assert_includes texto, "Encuentro: Ruta al páramo"
    assert_includes texto, "de 19:00 a 21:00 · Parque de la 93"
    assert_includes texto, "propón puntos en COMUNIA: http://www.example.com#{@base}"
    assert_not_includes texto, "Cuotas", "el orden del día no sale de COMUNIA"

    sign_in @socio
    get @base
    assert_not_includes response.body, "wa.me", "un socio no tiene el botón"
  end

  test "con el acta publicada avisa de que ya está, sin copiarla; antes de eso y ya pasada, no hay botón" do
    @reunion.update_columns(inicio: 2.days.ago, fin: 2.days.ago + 2.hours, estado: Reunion.estados[:celebrada],
                            acta: "Se aprobó subir la cuota")
    sign_in @admin
    get @base
    assert_not_includes response.body, "wa.me"

    @reunion.update_column(:acta_publicada_at, Time.current)
    get @base
    assert_includes response.body, "Avisar del acta por WhatsApp"
    texto = mensaje_whatsapp
    assert_includes texto, "Ya está publicada el acta de «Ruta al páramo»"
    assert_not_includes texto, "cuota"
  end

  private

  def mensaje_whatsapp
    href = response.body[%r{href="(https://wa\.me/\?text=[^"]+)"}, 1]
    assert href, "falta el botón de WhatsApp"
    CGI.unescape(CGI.unescapeHTML(href).split("text=", 2).last)
  end

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                    cedula: SecureRandom.hex(4), estado: :activo)
    user
  end
end
