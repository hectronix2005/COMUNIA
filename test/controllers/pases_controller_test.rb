require "test_helper"

class PasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dir = Dir.mktmpdir
    @pkey = OpenSSL::PKey::RSA.new(2048)
    File.write("#{@dir}/#{Time.now.utc.strftime('%Y-%m')}.pem", @pkey.to_pem)
    @env_antes = ENV["PASES_DIR"]
    ENV["PASES_DIR"] = @dir

    rol = Rol.create!(nombre: "R #{SecureRandom.hex(4)}", codigo: "r_#{SecureRandom.hex(4)}")
    @logia = Logia.create!(nombre: "L", slug: "l-#{SecureRandom.hex(4)}", codigo: "L#{rand(100_000)}")
    @user = User.create!(nombre: "A", apellido: "B", email: "a_#{SecureRandom.hex(4)}@test.com",
                         password: "password123", logia: @logia, rol_ref: rol)
    @miembro = Miembro.create!(user: @user, logia: @logia, numero_miembro: "M#{rand(100_000)}", cedula: rand(100_000).to_s)
  end

  teardown do
    ENV["PASES_DIR"] = @env_antes
    FileUtils.remove_entry(@dir)
  end

  def kid = Pases.b64(OpenSSL::Digest::SHA256.digest(@pkey.public_to_der))
  def cegado = OpenSSL::BN.rand_range(@pkey.n).to_s(2).rjust(256, "\0")

  test "claves.json es público y trae la clave en JWK y el sello" do
    get "/pases/claves.json", headers: { "User-Agent" => "denunciapp/1.0" }
    assert_response :success
    cuerpo = response.parsed_body
    assert_equal [kid], cuerpo["claves"].map { |c| c["kid"] }
    assert_equal Pases.b64(@pkey.n.to_s(2)), cuerpo["claves"].first["n"]
    assert_equal false, cuerpo["sello_publico"]
    assert_match "public", response.headers["Cache-Control"]
  end

  test "firmar exige sesión" do
    post "/pases/firmar", params: { kid: kid, cegado: Pases.b64(cegado) }, as: :json
    assert_response :unauthorized
  end

  test "un miembro activo obtiene 4 firmas válidas por semana y la quinta se rechaza" do
    sign_in @user, scope: :user
    4.times do
      m = cegado
      post "/pases/firmar", params: { kid: kid, cegado: Pases.b64(m) }, as: :json
      assert_response :success
      firma = Pases.desde_b64(response.parsed_body["firma_cegada"])
      assert_equal OpenSSL::BN.new(m, 2), OpenSSL::BN.new(firma, 2).mod_exp(@pkey.e, @pkey.n)
    end
    post "/pases/firmar", params: { kid: kid, cegado: Pases.b64(cegado) }, as: :json
    assert_response :too_many_requests
  end

  test "un miembro no activo no recibe pases" do
    @miembro.update_columns(estado: Miembro.estados[:quite])
    sign_in @user, scope: :user
    post "/pases/firmar", params: { kid: kid, cegado: Pases.b64(cegado) }, as: :json
    assert_response :forbidden
  end

  test "kid de otra época da 409 y un mensaje mal formado da 422 sin gastar cupo" do
    sign_in @user, scope: :user
    post "/pases/firmar", params: { kid: "otro", cegado: Pases.b64(cegado) }, as: :json
    assert_response :conflict
    post "/pases/firmar", params: { kid: kid, cegado: "%%%" }, as: :json
    assert_response :unprocessable_entity
    post "/pases/firmar", params: { kid: kid, cegado: Pases.b64("\xFF".b * 256) }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, PaseSemanal.where(miembro: @miembro).sum(:cantidad)
  end

  test "sin clave del mes no se firma" do
    FileUtils.rm(Dir["#{@dir}/*.pem"])
    sign_in @user, scope: :user
    post "/pases/firmar", params: { kid: kid, cegado: Pases.b64(cegado) }, as: :json
    assert_response :service_unavailable
  end
end
