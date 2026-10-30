require "test_helper"

# El chat solo se escucha siendo de la comunidad (o de una que se comparta, en los privados), aunque se guarde el
# nombre firmado del stream: la firma no caduca.
class ChatStreamsChannelTest < ActionCable::Channel::TestCase
  setup do
    rol = Rol.find_or_create_by!(codigo: "miembro") { _1.nombre = "Miembro" }
    @luz = Logia.create!(nombre: "Logia Luz", slug: "luz-#{SecureRandom.hex(2)}", codigo: "L#{SecureRandom.hex(3).upcase}")
    @andes = Logia.create!(nombre: "Egresados Andes", slug: "andes-#{SecureRandom.hex(2)}", codigo: "A#{SecureRandom.hex(3).upcase}")
    crear = ->(nombre, logia) do
      User.create!(nombre: nombre, apellido: "Prueba", email: "#{nombre.downcase}_#{SecureRandom.hex(3)}@correo.co",
                   password: "password123", logia: logia, rol_ref: rol)
    end
    @lucia = crear.("Lucia", @luz)
    @mario = crear.("Mario", @luz)
    @andres = crear.("Andres", @andes)
  end

  test "el chat de la comunidad, solo para los suyos" do
    escuchar(@lucia, "chat_logia_#{@luz.id}")
    assert subscription.confirmed?
    assert_has_stream "chat_logia_#{@luz.id}"

    escuchar(@andres, "chat_logia_#{@luz.id}")
    assert subscription.rejected?
  end

  test "quien deja la comunidad deja de escuchar su chat" do
    @andres.unir_a_comunidad!(@luz)
    escuchar(@andres, "chat_tenant_#{@luz.id}")
    assert subscription.confirmed?

    @andres.salir_de_comunidad!(@luz)
    escuchar(@andres, "chat_tenant_#{@luz.id}")
    assert subscription.rejected?
  end

  test "un privado, solo para sus dos y mientras compartan comunidad" do
    dm = "chat_dm_#{[@lucia.id, @mario.id].sort.join('_')}"
    escuchar(@lucia, dm)
    assert subscription.confirmed?

    escuchar(@andres, dm)
    assert subscription.rejected?

    escuchar(@andres, "chat_dm_#{[@lucia.id, @andres.id].sort.join('_')}")
    assert subscription.rejected?
  end

  test "un nombre sin firma o desconocido no se escucha" do
    stub_connection current_user: @lucia
    subscribe signed_stream_name: "chat_logia_#{@luz.id}"
    assert subscription.rejected?

    escuchar(@lucia, "otra_cosa_#{@luz.id}")
    assert subscription.rejected?
  end

  private

  def escuchar(user, stream)
    stub_connection current_user: user
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name(stream)
  end
end
