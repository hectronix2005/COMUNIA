require "test_helper"

class ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @rol = Rol.create!(nombre: "Test Role #{SecureRandom.hex(4)}", codigo: "test_#{SecureRandom.hex(4)}")
    @logia = Logia.create!(nombre: "Test Logia", slug: "test-logia-#{SecureRandom.hex(4)}", codigo: "TL#{rand(1000)}")
    @alice = User.create!(nombre: "Alice", apellido: "Sender", email: "alice_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: @logia, rol_ref: @rol)
    @bob = User.create!(nombre: "Bob", apellido: "Receiver", email: "bob_#{SecureRandom.hex(4)}@test.com", password: "password123", logia: @logia, rol_ref: @rol)
    Miembro.create!(user: @alice, logia: @logia, numero_miembro: "M#{rand(100000)}", cedula: rand(100000).to_s.rjust(6, "0"))
    Miembro.create!(user: @bob, logia: @logia, numero_miembro: "M#{rand(100000)}", cedula: rand(100000).to_s.rjust(6, "0"))
    sign_in @alice, scope: :user
  end

  test "index loads default channel" do
    get chat_path
    assert_response :success
  end

  test "index loads logia channel" do
    get chat_path(canal: "logia")
    assert_response :success
  end

  test "index loads DM conversation" do
    get chat_path(con: @bob.id)
    assert_response :success
  end

  test "index redirects for invalid DM" do
    get chat_path(con: 999999)
    assert_redirected_to chat_path
  end

  test "index marks DMs as read" do
    msg = ChatMensaje.create!(logia: @logia, user: @bob, destinatario: @alice, contenido: "Unread", canal: "dm")
    get chat_path(con: @bob.id)
    msg.reload
    assert_not_nil msg.leido_at
  end

  test "create DM message" do
    assert_difference "ChatMensaje.count" do
      post chat_path(con: @bob.id), params: { contenido: "Hello Bob" }
    end
    assert_response :ok
    assert_equal "dm", ChatMensaje.last.canal
  end

  test "create logia message" do
    assert_difference "ChatMensaje.count" do
      post chat_path(canal: "logia"), params: { contenido: "Hello logia" }
    end
    assert_response :ok
  end

  test "create rejects empty content" do
    assert_no_difference "ChatMensaje.count" do
      post chat_path, params: { contenido: "" }
    end
    assert_response :unprocessable_entity
  end

  test "create blocks invalid DM recipient" do
    post chat_path(con: 999999), params: { contenido: "Hack" }
    assert_response :forbidden
  end

  test "reaccionar toggles emoji" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "React", canal: "dm")
    post chat_reaccionar_path, params: { id: msg.id, emoji: "👍" }
    assert_response :ok
    msg.reload
    assert_includes msg.reacciones["👍"], @alice.id
  end

  test "reaccionar rejects invalid emoji" do
    msg = ChatMensaje.create!(logia: @logia, user: @alice, contenido: "React", canal: "logia")
    post chat_reaccionar_path, params: { id: msg.id, emoji: "💀" }
    assert_response :unprocessable_entity
  end

  test "buscar returns matching messages" do
    ChatMensaje.create!(logia: @logia, user: @alice, destinatario: @bob, contenido: "Hola mundo especial", canal: "dm")
    get chat_buscar_path(q: "especial", canal: "dm", con: @bob.id)
    assert_response :success
    assert_match "especial", response.body
  end

  test "buscar ignores short queries" do
    get chat_buscar_path(q: "H", canal: "dm", con: @bob.id)
    assert_response :ok
    assert_equal "", response.body
  end

  test "marcar_leido works" do
    msg = ChatMensaje.create!(logia: @logia, user: @bob, destinatario: @alice, contenido: "Read me", canal: "dm")
    post chat_marcar_leido_path, params: { id: msg.id }
    assert_response :ok
    msg.reload
    assert msg.leido?
  end

  test "typing returns ok" do
    post chat_typing_path, params: { stream: "chat_dm_#{[@alice.id, @bob.id].sort.join('_')}" }
    assert_response :ok
  end

  test "typing rejects empty stream" do
    post chat_typing_path, params: { stream: "" }
    assert_response :forbidden
  end
end
