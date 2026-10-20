require "test_helper"

class PasesTest < ActiveSupport::TestCase
  # Clave RSA a partir de p, q y e del vector, vía la estructura RSAPrivateKey (PKCS#1).
  def clave_del_vector(v)
    p, q, e, d = %w[p q e d].map { |k| OpenSSL::BN.new(v[k], 16) }
    n = p * q
    uno = OpenSSL::BN.new(1)
    der = OpenSSL::ASN1::Sequence([0, n, e, d, p, q, d % (p - uno), d % (q - uno), q.mod_inverse(p)]
                                    .map { |x| OpenSSL::ASN1::Integer(x) }).to_der
    OpenSSL::PKey::RSA.new(der)
  end

  def vector
    @vector ||= file_fixture("rfc9474_a1.txt").readlines
                  .reject { |l| l.start_with?("#") }
                  .to_h { |l| l.strip.split(" = ") }
  end

  def hex(k) = [vector.fetch(k)].pack("H*")

  test "RFC 9474 A.1: BlindSign da blind_sig y el resultado descegado verifica como RSA-PSS SHA-384" do
    pkey = clave_del_vector(vector)
    assert_equal vector["n"], pkey.n.to_s(16).downcase
    clave = Pases::Claves::Clave.new(pkey: pkey, desde: Time.utc(2026, 10), hasta: Time.utc(2026, 11))

    blind_sig = Pases::Firmante.firmar(clave, hex("blinded_msg"))
    assert_equal vector["blind_sig"], blind_sig.unpack1("H*")

    # Lo que hace el navegador: sig = blind_sig · inv mod n, y DENUNCIAPP lo verifica.
    sig = (OpenSSL::BN.new(blind_sig, 2) * OpenSSL::BN.new(vector["inv"], 16)) % pkey.n
    assert_equal vector["sig"], sig.to_s(16).downcase.rjust(vector["sig"].size, "0")
    assert pkey.verify("SHA384", [vector["sig"]].pack("H*"), hex("prepared_msg"),
                       rsa_padding_mode: "pss", rsa_pss_saltlen: 48, rsa_mgf1_md: "SHA384")
  end

  test "el firmante rechaza mensajes de otro tamaño o mayores que el módulo" do
    clave = Pases::Claves::Clave.new(pkey: OpenSSL::PKey::RSA.new(2048), desde: Time.utc(2026, 10), hasta: Time.utc(2026, 11))
    assert_raises(Pases::Firmante::Error) { Pases::Firmante.firmar(clave, "x" * 255) }
    assert_raises(Pases::Firmante::Error) { Pases::Firmante.firmar(clave, "\xFF".b * 256) }
    assert_not Pases::Firmante.valido?(clave, nil)
  end

  test "claves: publica la del mes anterior y la actual, no la siguiente, y descarta las débiles" do
    Dir.mktmpdir do |dir|
      %w[2026-09 2026-10 2026-11].each { |m| File.write("#{dir}/#{m}.pem", OpenSSL::PKey::RSA.new(2048).to_pem) }
      File.write("#{dir}/2026-08.pem", OpenSSL::PKey::RSA.new(1024).to_pem)
      con_env("PASES_DIR" => dir) do
        ahora = Time.utc(2026, 10, 19, 22)
        publicadas = Pases::Claves.publicadas(ahora)
        assert_equal [Time.utc(2026, 9), Time.utc(2026, 10)], publicadas.map(&:desde)
        assert_equal publicadas.first.hasta, publicadas.last.desde
        assert_equal publicadas.last.kid, Pases::Claves.actual(ahora).kid
        assert_equal %i[kid n e desde hasta], publicadas.last.jwk.keys
        assert_equal "AQAB", publicadas.last.jwk[:e]

        assert_equal [Time.utc(2026, 9)], Pases::Claves.publicadas(Time.utc(2026, 9, 2)).map(&:desde)
        assert_nil Pases::Claves.de_la_epoca(Time.utc(2026, 8))
      end
    end
  end

  test "pases semanales: como mucho 4 por semana ISO y miembro" do
    rol = Rol.create!(nombre: "R #{SecureRandom.hex(4)}", codigo: "r_#{SecureRandom.hex(4)}")
    logia = Logia.create!(nombre: "L", slug: "l-#{SecureRandom.hex(4)}", codigo: "L#{rand(100_000)}")
    user = User.create!(nombre: "A", apellido: "B", email: "a_#{SecureRandom.hex(4)}@test.com",
                        password: "password123", logia: logia, rol_ref: rol)
    miembro = Miembro.create!(user: user, logia: logia, numero_miembro: "M#{rand(100_000)}", cedula: rand(100_000).to_s)
    lunes = Time.zone.local(2026, 10, 19, 9)

    4.times { assert PaseSemanal.reservar(miembro, lunes) }
    assert_not PaseSemanal.reservar(miembro, lunes + 6.days)
    assert PaseSemanal.reservar(miembro, lunes + 7.days)
    assert_equal [4, 1], PaseSemanal.where(miembro: miembro).order(:semana).pluck(:cantidad)
  end

  private

  def con_env(vars)
    antes = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    antes.each { |k, v| ENV[k] = v }
  end
end
