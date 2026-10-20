require "test_helper"

# Traspaso, sección 5, pruebas 33–43 (tests/pases.test.ts de DENUNCIAPP).
class Denuncias::PasesTest < ActionDispatch::IntegrationTest
  include DenunciasPrueba

  P = Denuncias::Pases
  b64 = ->(s) { Base64.urlsafe_encode64(s, padding: false) }
  B64 = b64

  def self.clave_json(pkey, desde, hasta, kid: nil)
    { "kid" => kid || B64.(OpenSSL::Digest::SHA256.digest(pkey.public_to_der)), "n" => B64.(pkey.n.to_s(2)),
      "e" => B64.(pkey.e.to_s(2)), "desde" => desde.utc.iso8601, "hasta" => hasta.utc.iso8601 }
  end

  CLAVE = OpenSSL::PKey::RSA.new(2048)
  OTRA = OpenSSL::PKey::RSA.new(2048)
  MES = Time.utc(Time.now.utc.year, Time.now.utc.month)

  def claves_json(sello: false, claves: [self.class.clave_json(CLAVE, MES, MES.next_month)])
    { "claves" => claves, "sello_publico" => sello }
  end

  # Un pase válido = msg preparado de 64 bytes + firma RSA-PSS SHA-384 (sal 48) con la clave del mes,
  # que es lo que da Finalize tras la firma ciega.
  def pase(clave: CLAVE, kid: nil, msg: SecureRandom.random_bytes(64), extra: {})
    firma = clave.sign_pss("SHA384", msg, salt_length: 48, mgf1_hash: "SHA384")
    kid ||= B64.(OpenSSL::Digest::SHA256.digest(clave.public_to_der))
    B64.({ "kid" => kid, "msg" => B64.(msg), "firma" => B64.(firma) }.merge(extra).to_json)
  end

  def vector = @vector ||= file_fixture("rfc9474_a1.txt").readlines.reject { _1.start_with?("#") }.to_h { _1.strip.split(" = ") }
  def hex(k) = [vector.fetch(k)].pack("H*")

  def clave_vector
    p, q, e, d = %w[p q e d].map { OpenSSL::BN.new(vector[_1], 16) }
    uno = OpenSSL::BN.new(1)
    OpenSSL::PKey::RSA.new(OpenSSL::ASN1::Sequence([0, p * q, e, d, p, q, d % (p - uno), d % (q - uno), q.mod_inverse(p)]
                                                    .map { OpenSSL::ASN1::Integer(_1) }).to_der)
  end

  setup { preparar_denuncias(claves_json: claves_json) }
  teardown { limpiar_denuncias }

  test "33. RFC 9474 A.1: verifica la firma del vector y rechaza una alterada o sobre el msg sin prefijo" do
    k = clave_vector
    sig = hex("sig")
    assert k.verify_pss("SHA384", sig, hex("prepared_msg"), salt_length: 48, mgf1_hash: "SHA384")
    alterada = sig.dup.tap { _1.setbyte(10, _1.getbyte(10) ^ 1) }
    assert_not k.verify_pss("SHA384", alterada, hex("prepared_msg"), salt_length: 48, mgf1_hash: "SHA384")
    assert_not k.verify_pss("SHA384", sig, hex("msg"), salt_length: 48, mgf1_hash: "SHA384")
  end

  test "34. RFC 9474 A.1: Finalize(blind_sig, inv) da sig" do
    k = clave_vector
    s = (OpenSSL::BN.new(hex("blind_sig"), 2) * OpenSSL::BN.new(hex("inv"), 2)) % k.n
    assert_equal vector["sig"], s.to_s(16).downcase.rjust(vector["sig"].size, "0")
  end

  test "35. RFC 9474 A.1: BlindSign(blinded_msg) con la clave privada del vector da blind_sig" do
    clave = ::Pases::Claves::Clave.new(pkey: clave_vector, desde: MES, hasta: MES.next_month)
    assert_equal vector["blind_sig"], ::Pases::Firmante.firmar(clave, hex("blinded_msg")).unpack1("H*")
  end

  test "36. claves.json: acepta 1 o 2 claves contiguas y recalcula el kid" do
    uno = P.leer_claves(claves_json)
    assert_equal 1, uno.claves.size
    dos = P.leer_claves(claves_json(claves: [self.class.clave_json(CLAVE, MES, MES.next_month),
                                             self.class.clave_json(OTRA, MES.prev_month, MES)]))
    assert_equal [MES.prev_month, MES], dos.claves.map(&:desde)
    # Y el claves.json que publica COMUNIA de verdad también pasa estas reglas.
    Dir.mktmpdir do |dir|
      File.write("#{dir}/#{MES.strftime('%Y-%m')}.pem", CLAVE.to_pem)
      antes, ENV["PASES_DIR"] = ENV["PASES_DIR"], dir
      host! "www.example.com"
      get "/pases/claves.json"
      assert P.leer_claves(JSON.parse(response.body))
    ensure
      ENV["PASES_DIR"] = antes
    end
  end

  test "37. claves.json: rechaza el archivo entero ante cualquier anomalía" do
    ok = self.class.clave_json(CLAVE, MES, MES.next_month)
    debil = OpenSSL::PKey::RSA.new(1024)
    e3 = OpenSSL::PKey::RSA.new(OpenSSL::ASN1::Sequence([OpenSSL::ASN1::Integer(CLAVE.n), OpenSSL::ASN1::Integer(3)]).to_der)
    malos = {
      "3 claves" => claves_json(claves: [ok, self.class.clave_json(OTRA, MES.prev_month, MES), self.class.clave_json(OpenSSL::PKey::RSA.new(2048), MES.next_month, MES.next_month.next_month)]),
      "solape" => claves_json(claves: [ok, self.class.clave_json(OTRA, MES - 86_400, MES + 86_400)]),
      "1024 bits" => claves_json(claves: [self.class.clave_json(debil, MES, MES.next_month)]),
      "e = 3" => claves_json(claves: [self.class.clave_json(e3, MES, MES.next_month)]),
      "kid ajeno" => claves_json(claves: [self.class.clave_json(CLAVE, MES, MES.next_month, kid: B64.("x" * 32))]),
      "campo de más en la clave" => claves_json(claves: [ok.merge("logia" => "x")]),
      "sello_publico no booleano" => claves_json.merge("sello_publico" => "true"),
      "campo de más arriba" => claves_json.merge("comunidad" => "x"),
      "lista vacía" => claves_json(claves: [])
    }
    malos.each { |caso, json| assert_raises(P::ClavesInvalidas, caso) { P.leer_claves(json) } }
  end

  test "38. si llega un archivo malo, conserva las últimas claves buenas" do
    fuente = claves_json
    almacen = P::Almacen.new(fuente: -> { fuente }, cada: 0)
    assert almacen.clave(JSON.parse(Base64.urlsafe_decode64(pase))["kid"])
    fuente = { "claves" => [], "sello_publico" => true }
    assert_not almacen.refrescar
    assert almacen.clave(B64.(OpenSSL::Digest::SHA256.digest(CLAVE.public_to_der)))
    assert_not almacen.sello_publico?
  end

  test "39. verificarPase: válido; no lo son el falsificado, el de otra clave, el mal formado ni el de clave aún no vigente" do
    assert P.verificar(pase)
    falsificado = B64.(JSON.parse(Base64.urlsafe_decode64(pase)).merge("msg" => B64.(SecureRandom.random_bytes(64))).to_json)
    assert_nil P.verificar(falsificado)
    assert_nil P.verificar(pase(clave: OTRA))
    assert_nil P.verificar(pase(clave: OTRA, kid: B64.(OpenSSL::Digest::SHA256.digest(CLAVE.public_to_der))))
    assert_nil P.verificar(pase(extra: { "logia" => "x" }))
    assert_nil P.verificar("no es base64!")
    assert_nil P.verificar("A" * 4097)
    assert_nil P.verificar(pase(msg: SecureRandom.random_bytes(48)))
    futura = P::Almacen.new(fuente: -> { claves_json(claves: [self.class.clave_json(CLAVE, MES.next_month, MES.next_month.next_month)]) })
    assert_nil P.verificar(pase, futura)
  end

  test "40. un pase válido da sello; el reusado, el falsificado o sin pase entran sin sello" do
    p = pase
    r1 = JSON.parse(publicar(pase: p).body)
    assert_equal ["aplicado", false], r1.values_at("sello", "selloPublico")
    r2 = publicar(pase: p)
    assert_equal 201, r2.status
    assert_equal "pase_usado", JSON.parse(r2.body)["sello"]
    assert_equal "pase_invalido", JSON.parse(publicar(pase: pase(clave: OTRA)).body)["sello"]
    r4 = JSON.parse(publicar.body)
    assert_nil r4["sello"]
    assert_equal [true, false, false, false], Denuncias::Reporte.order(:n).pluck(:verificada)
  end

  test "41. no guarda kid, msg ni firma; pases_usados solo tiene el hash" do
    p = pase
    datos = JSON.parse(Base64.urlsafe_decode64(p))
    publicar(pase: p)
    volcado = %w[reportes eventos_custodia evidencias].map { ActiveRecord::Base.connection.select_all("SELECT * FROM denuncias_#{_1}").to_a }.to_json
    datos.each_value { assert_not_includes volcado, _1 }
    assert_equal ["sha256"], Denuncias::PaseUsado.column_names
    assert_equal [Denuncias::Cripto.sha256_hex(Base64.urlsafe_decode64(datos["msg"] + "=" * (-datos["msg"].size % 4)))],
                 Denuncias::PaseUsado.pluck(:sha256)
  end

  test "42. el sello no sale en público mientras sello_publico sea false, y se congela por denuncia" do
    id1 = JSON.parse(publicar(pase: pase).body)["id"]
    Denuncias::Pases.almacen = P::Almacen.new(fuente: -> { claves_json(sello: true) })
    id2 = JSON.parse(publicar(pase: pase).body)["id"]
    lista = muro.index_by { _1["id"] }
    assert_equal false, lista[id1]["verificada"] # recibida con sello oculto: se queda oculto
    assert_equal true, lista[id2]["verificada"]
    lista.each_value do |r|
      assert_match(/\A\d{4}-\d{2}-\d{2}\z/, r["fecha"])
      assert_not r.key?("creado_en")
      assert_not r.key?("sello_publico")
    end
    pdf, = Denuncias::Paquete.generar(Denuncias::Reporte.find(id1), "Fiscalía")
    assert pdf.start_with?("%PDF-")
  end

  test "43. sin claves configuradas, un pase no da sello" do
    Denuncias::Pases.almacen = P::Almacen.new(fuente: -> { raise "sin claves" })
    assert_equal "pase_invalido", JSON.parse(publicar(pase: pase).body)["sello"]
    assert_equal [false], Denuncias::Reporte.pluck(:verificada)
  end
end
