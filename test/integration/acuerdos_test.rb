require "test_helper"

# Acuerdos de la reunión: quien la gestiona los apunta con responsable y fecha; quien se encarga recibe un aviso, lo
# ve en su panel y lo da por cumplido. Lo que queda sin cumplir sale en la siguiente convocatoria del mismo grupo.
class AcuerdosTest < ActionDispatch::IntegrationTest
  setup do
    @rol_miembro = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @rol_admin = Rol.find_or_create_by!(codigo: "admin_logia") { _1.nombre = "Admin de logia" }
    @club = Categoria.create!(nombre: "Club #{SecureRandom.hex(3)}", termino_reunion: "Encuentro",
                              modulos: %w[reuniones tesoreria])
    @mercedes = logia("Mercedes", categoria: @club)
    @suv = logia("SUV", tenant: @mercedes)
    @clasicos = logia("Clásicos", tenant: @mercedes)
    @admin, = persona("Ada", @suv, rol_ref: @rol_admin)
    @socio, @ficha_socio = persona("Sara", @suv)
    @otro_socio, = persona("Simón", @suv)
    _, @ficha_vecino = persona("Vera", @clasicos)
    @pasada = reunion(2.days.ago, "Ruta")
    @siguiente = reunion(5.days.from_now, "Cena")
    @base = "/t/#{@mercedes.slug}/reuniones"
  end

  test "se apunta con responsable, se le avisa, lo ve en su panel y en la siguiente, y lo cumple" do
    sign_in @admin
    post "#{@base}/#{@pasada.id}/acuerdos",
         params: { reunion_acuerdo: { texto: "Reservar el salón", responsable_id: @ficha_socio.id, vence_el: 3.days.from_now.to_date } }
    assert_redirected_to "#{@base}/#{@pasada.id}#acuerdos"
    acuerdo = @pasada.reunion_acuerdos.sole
    assert_equal @ficha_socio, acuerdo.responsable
    assert_equal [@socio.id], Notificacion.where(tipo: "reunion_acuerdo").pluck(:user_id)

    sign_in @socio
    get "/t/#{@mercedes.slug}/dashboard"
    assert_select "#mis-acuerdos", text: /Reservar el salón/
    get "#{@base}/#{@siguiente.id}"
    assert_includes response.body, "Pendiente de antes"
    assert_includes response.body, "Te encargas tú"

    sign_in @otro_socio
    post "#{@base}/#{@pasada.id}/acuerdos/#{acuerdo.id}/cumplir"
    assert_not acuerdo.reload.cumplido?, "otro socio no lo da por cumplido"
    get "#{@base}/#{@siguiente.id}"
    assert_includes response.body, "Se encarga Sara Prueba"

    sign_in @socio
    post "#{@base}/#{@siguiente.id}/acuerdos/#{acuerdo.id}/cumplir", params: { desde: "panel" }
    assert_redirected_to "/t/#{@mercedes.slug}/dashboard"
    assert acuerdo.reload.cumplido?
    get "#{@base}/#{@siguiente.id}"
    assert_not_includes response.body, "Pendiente de antes"
  end

  test "un socio no apunta ni borra, no se apunta antes de empezar y el responsable es un convocado" do
    sign_in @socio
    post "#{@base}/#{@pasada.id}/acuerdos", params: { reunion_acuerdo: { texto: "Intruso" } }
    assert_equal 0, ReunionAcuerdo.count

    sign_in @admin
    post "#{@base}/#{@siguiente.id}/acuerdos", params: { reunion_acuerdo: { texto: "Antes de tiempo" } }
    post "#{@base}/#{@pasada.id}/acuerdos", params: { reunion_acuerdo: { texto: "De otro grupo", responsable_id: @ficha_vecino.id } }
    assert_equal 0, ReunionAcuerdo.count

    post "#{@base}/#{@pasada.id}/acuerdos", params: { reunion_acuerdo: { texto: "Sin responsable" } }
    acuerdo = ReunionAcuerdo.sole
    assert_equal 0, Notificacion.where(tipo: "reunion_acuerdo").count
    sign_in @socio
    delete "#{@base}/#{@pasada.id}/acuerdos/#{acuerdo.id}"
    assert ReunionAcuerdo.exists?(acuerdo.id)
    sign_in @admin
    delete "#{@base}/#{@pasada.id}/acuerdos/#{acuerdo.id}"
    assert_not ReunionAcuerdo.exists?(acuerdo.id)
  end

  private

  def reunion(inicio, titulo)
    Reunion.create!(logia: @suv, user: @admin, titulo: titulo, inicio: inicio, fin: inicio + 2.hours)
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
