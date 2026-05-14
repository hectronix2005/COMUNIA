require "test_helper"

class ChatMensajeTest < ActiveSupport::TestCase
  setup do
    @rol = Rol.create!(nombre: "Test Miembro #{SecureRandom.hex(4)}", codigo: "test_#{SecureRandom.hex(4)}")
    @logia = Logia.create!(nombre: "Test Logia", slug: "test-logia-#{SecureRandom.hex(4)}", codigo: "TL#{rand(1000)}")
    @alice = User.create!(nombre: "Alice", apellido: "Test", email: "alice_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: @logia, rol_ref: @rol)
    @bob = User.create!(nombre: "Bob", apellido: "Test", email: "bob_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: @logia, rol_ref: @rol)
    Miembro.create!(user: @alice, logia: @logia, numero_miembro: "M#{rand(100000)}", cedula: rand(100000).to_s.rjust(6, "0"))
    Miembro.create!(user: @bob, logia: @logia, numero_miembro: "M#{rand(100000)}", cedula: rand(100000).to_s.rjust(6, "0"))
  end

  test "creates a valid DM" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Hola", canal: "dm")
    assert msg.dm?
    assert msg.persisted?
  end

  test "stream_name is symmetrical for DMs" do
    msg1 = ChatMensaje.new(user_id: @alice.id, destinatario_id: @bob.id, canal: "dm", logia: @logia, contenido: "x")
    msg2 = ChatMensaje.new(user_id: @bob.id, destinatario_id: @alice.id, canal: "dm", logia: @logia, contenido: "y")
    assert_equal msg1.stream_name, msg2.stream_name
  end

  test "marcar_leido sets leido_at for recipient" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Test", canal: "dm")
    assert_nil msg.leido_at
    msg.marcar_leido!(@bob)
    msg.reload
    assert_not_nil msg.leido_at
    assert msg.leido?
  end

  test "marcar_leido does nothing for sender" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Test", canal: "dm")
    msg.marcar_leido!(@alice)
    msg.reload
    assert_nil msg.leido_at
  end

  test "marcar_leido does nothing for channel messages" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, contenido: "Test", canal: "logia")
    msg.marcar_leido!(@bob)
    msg.reload
    assert_nil msg.leido_at
  end

  test "toggle_reaccion adds and removes" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Test", canal: "dm")
    msg.toggle_reaccion!(@bob, "👍")
    msg.reload
    assert_includes msg.reacciones["👍"], @bob.id

    msg.toggle_reaccion!(@bob, "👍")
    msg.reload
    assert_empty msg.reacciones
  end

  test "toggle_reaccion rejects invalid emoji" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Test", canal: "dm")
    msg.toggle_reaccion!(@bob, "💀")
    msg.reload
    assert_empty msg.reacciones
  end

  test "unread_dm_for scope" do
    ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Unread", canal: "dm")
    ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Read", canal: "dm", leido_at: Time.current)
    unread = ChatMensaje.unread_dm_for(@bob.id).where(user_id: @alice.id)
    assert_equal 1, unread.count
  end

  test "ultimo_mensaje_dm returns latest per partner" do
    ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Older", canal: "dm", created_at: 1.hour.ago)
    ChatMensaje.create!(logia: @logia, user: @bob, destinatario: @alice, contenido: "Newer", canal: "dm", created_at: 5.minutes.ago)
    result = ChatMensaje.ultimo_mensaje_dm(@alice.id)
    assert result.key?(@bob.id)
    assert_equal "Newer", result[@bob.id].contenido
  end

  test "dm_entre returns both directions" do
    ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "A->B", canal: "dm")
    ChatMensaje.create!(logia: @logia, user: @bob, destinatario: @alice, contenido: "B->A", canal: "dm")
    msgs = ChatMensaje.dm_entre(@alice.id, @bob.id)
    assert_equal 2, msgs.count
    assert msgs.all?(&:dm?)
  end

  test "validates contenido presence" do
    msg = ChatMensaje.new(logia: @logia, user: @alice, canal: "logia", contenido: "")
    assert_not msg.valid?
  end

  test "validates contenido max length" do
    msg = ChatMensaje.new(logia: @logia, user: @alice, canal: "logia", contenido: "x" * 1001)
    assert_not msg.valid?
  end

  test "validates canal inclusion" do
    msg = ChatMensaje.new(logia: @logia, user: @alice, contenido: "test", canal: "invalid")
    assert_not msg.valid?
  end
end
