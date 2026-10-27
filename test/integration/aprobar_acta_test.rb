require "test_helper"

# Aprobar el acta anterior: en la siguiente reunión del grupo sale el acta publicada de la anterior para leerla, y
# desde que empieza quien la gestiona la da por aprobada. Aprobada, ya no se corrige (salvo deshaciendo la aprobación).
class AprobarActaTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @admin = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio = persona("Sara", @suv)
    @vieja = celebrada(@suv, 30.days.ago, "Asamblea vieja")
    @pasada = celebrada(@suv, 10.days.ago, "Ruta al páramo")
    celebrada(@clasicos, 5.days.ago, "De otro grupo")
    @base = "/t/#{@mercedes.slug}/reuniones"
  end

  test "antes de empezar se lee; desde que empieza quien gestiona la aprueba y ya no se corrige" do
    siguiente = reunion(3.days.from_now, "Cena")
    sign_in @socio
    get "#{@base}/#{siguiente.id}"
    assert_select "#acta-anterior", text: /Ruta al páramo.*Léela antes: se aprueba en esta reunión/m
    assert_not_includes response.body, "Asamblea vieja", "solo la última acta publicada"
    assert_not_includes response.body, "De otro grupo"

    sign_in @admin
    get "#{@base}/#{siguiente.id}"
    assert_select "#acta-anterior form", count: 0, message: "antes de empezar no se aprueba"
    post "#{@base}/#{siguiente.id}/aprobar_acta_anterior"
    assert_not @pasada.reload.acta_aprobada?

    siguiente.update_columns(inicio: 1.hour.ago, fin: 1.hour.from_now)
    sign_in @socio
    post "#{@base}/#{siguiente.id}/aprobar_acta_anterior"
    assert_not @pasada.reload.acta_aprobada?, "un socio no aprueba"

    sign_in @admin
    post "#{@base}/#{siguiente.id}/aprobar_acta_anterior"
    assert_redirected_to "#{@base}/#{siguiente.id}#acta-anterior"
    assert_equal siguiente, @pasada.reload.acta_aprobada_en
    assert_not @vieja.reload.acta_aprobada?
    get "#{@base}/#{siguiente.id}"
    assert_select "#acta-anterior", text: /Se aprobó aquí el acta de\s+Ruta al páramo/
    get "#{@base}/#{@pasada.id}"
    assert_select "#acta", text: /Aprobada\s+en\s+Cena/
    assert_not_includes response.body, "Editar acta"

    patch "#{@base}/#{@pasada.id}", params: { reunion: { acta: "Otra cosa" } }
    assert_equal "Se aprobó la ruta", @pasada.reload.acta, "aprobada, no se corrige"

    post "#{@base}/#{siguiente.id}/deshacer_aprobacion", params: { acta_id: @pasada.id }
    assert_not @pasada.reload.acta_aprobada?
    patch "#{@base}/#{@pasada.id}", params: { reunion: { acta: "Se aprobó la ruta, con cambios" } }
    assert_equal "Se aprobó la ruta, con cambios", @pasada.reload.acta
  end

  test "sin acta publicada no sale nada, y solo se deshace lo aprobado en esa reunión" do
    @pasada.update_column(:acta_publicada_at, nil)
    @vieja.update_columns(acta_aprobada_at: 20.days.ago)
    siguiente = reunion(1.hour.ago, "Cena")
    sign_in @admin
    get "#{@base}/#{siguiente.id}"
    assert_select "#acta-anterior", count: 0

    post "#{@base}/#{siguiente.id}/deshacer_aprobacion", params: { acta_id: @vieja.id }
    assert_response :not_found
    assert @vieja.reload.acta_aprobada?
  end

  private

  def reunion(inicio, titulo)
    Reunion.create!(logia: @suv, user: @admin, titulo: titulo, inicio: inicio, fin: inicio + 2.hours)
  end

  def celebrada(logia, inicio, titulo)
    Reunion.create!(logia: logia, user: @admin, titulo: titulo, inicio: inicio, fin: inicio + 2.hours).tap do
      _1.update_columns(estado: Reunion.estados[:celebrada], acta: "Se aprobó la ruta", acta_publicada_at: inicio + 1.day)
    end
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
