require "test_helper"
require "pdf/reader"

# El acta en PDF: con la asistencia, el acta, los acuerdos y las votaciones cerradas (sin nombres si fue secreta).
# La publicada la descarga quien ve la reunión; el borrador, solo quien la gestiona.
class ActaPdfTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @admin, @ficha_admin = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio, @ficha_socio = persona("Sara", @suv)
    inicio = 3.days.ago.change(hour: 19)
    @reunion = Reunion.create!(logia: @suv, user: @admin, titulo: "Ruta al páramo", inicio: inicio, fin: inicio + 2.hours,
                               lugar: "Parque de la 93", orden_del_dia: "1. Ruta de diciembre")
    @reunion.update_columns(estado: Reunion.estados[:celebrada], acta: "Se aprobó la ruta por La Calera")
    @reunion.reunion_asistencias.create!(miembro: @ficha_socio)
    @reunion.reunion_acuerdos.create!(texto: "Reservar el bus", responsable: @ficha_socio, vence_el: 5.days.from_now.to_date)
    abierta = votacion("Subir la cuota", secreta: false)
    abierta.reunion_votos.create!(miembro: @ficha_socio, opcion: :si)
    abierta.update!(estado: :cerrada)
    secreta = votacion("Elegir tesorero", secreta: true)
    secreta.reunion_votos.create!(miembro: @ficha_admin, opcion: :no)
    secreta.update!(estado: :cerrada)
    @url = "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}/acta_pdf"
  end

  test "el borrador solo lo descarga quien gestiona; publicada, cualquiera que ve la reunión" do
    sign_in @socio
    get @url
    assert_redirected_to "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"

    sign_in @admin
    get @url
    assert_equal "application/pdf", response.media_type
    assert_includes texto_pdf, "BORRADOR"

    @reunion.update_column(:acta_publicada_at, Time.current)
    sign_in @socio
    get "/t/#{@mercedes.slug}/reuniones/#{@reunion.id}"
    assert_select "a[href='#{@url}']", text: /Descargar en PDF/
    get @url
    assert_match(/attachment; filename="acta-#{@reunion.inicio.to_date.iso8601}-ruta-al-paramo\.pdf"/, response.headers["Content-Disposition"])
    texto = texto_pdf
    ["Ruta al páramo", "Parque de la 93", "1. Ruta de diciembre", "1 de 2 convocados · quórum del 50 %", "Sara Prueba",
     "Se aprobó la ruta por La Calera", "Reservar el bus", "se encarga Sara Prueba", "pendiente de aprobar",
     "Subir la cuota", "Sí: Sara Prueba", "Elegir tesorero (secreta)", "0 sí, 1 no"].each do |esperado|
      assert_includes texto, esperado
    end
    assert_not_includes texto, "Ada Prueba", "en la secreta no salen nombres y Ada no asistió"
  end

  private

  def texto_pdf = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n").gsub(/\s+/, " ")

  def votacion(pregunta, secreta:)
    @reunion.reunion_votaciones.create!(user: @admin, pregunta: pregunta, secreta: secreta)
  end

  def logia(nombre, tenant: nil, categoria: nil)
    Logia.create!(nombre: nombre, slug: "#{nombre.parameterize}-#{SecureRandom.hex(3)}",
                  codigo: "L#{SecureRandom.hex(3).upcase}", tenant: tenant, categoria: categoria)
  end

  def persona(nombre, logia, rol_ref: @rol_miembro)
    user = User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.parameterize}_#{SecureRandom.hex(3)}@correo.co",
                        password: "password123", logia: logia, rol_ref: rol_ref,
                        rol: rol_ref == @rol_admin ? :admin_logia : :miembro)
    ficha = Miembro.create!(user: user, logia: logia, numero_miembro: "N#{SecureRandom.hex(3)}",
                            cedula: SecureRandom.hex(4), estado: :activo)
    [user, ficha]
  end
end
