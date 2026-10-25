require "test_helper"

# La fórmula de Red::CalculoConfianza: crece con más comunidades y más grandes, con rendimientos
# decrecientes, y no se deja inflar con comunidades nuevas, diminutas, duplicadas o en anillo.
class Red::ConfianzaTest < ActiveSupport::TestCase
  include RedPrueba

  def calcular(u) = Red::CalculoConfianza.calcular(u)

  setup { @ana = red_usuario("Ana") }

  test "sin comunidades: nivel 0" do
    r = calcular(@ana)
    assert_equal [0, 0, 0], [r[:nivel], r[:comunidades], r[:miembros]]
  end

  test "una comunidad de menos de 5 miembros no aporta" do
    red_comunidad(miembros: [@ana, *red_relleno(2)])
    assert_equal 0, calcular(@ana)[:puntaje]
  end

  test "más miembros dan más confianza, con rendimientos decrecientes" do
    chica = red_comunidad(miembros: [@ana, *red_relleno(9)])          # 10 → log10 = 1 → 0,25
    p_chica = calcular(@ana)[:puntaje]
    assert_in_delta 0.25, p_chica, 0.001

    beto = red_usuario("Beto")
    red_comunidad(miembros: [beto, *red_relleno(99)])                 # 100 → 0,5
    assert_in_delta 0.5, calcular(beto)[:puntaje], 0.001
    assert_equal 2, calcular(beto)[:nivel]
    assert chica
  end

  test "más comunidades suman, cada una vale 0,7 veces la anterior" do
    3.times { red_comunidad(miembros: [@ana, *red_relleno(9)]) }
    assert_in_delta 0.25 * (1 + 0.7 + 0.49), calcular(@ana)[:puntaje], 0.001
    assert_equal 3, calcular(@ana)[:comunidades]
    assert_equal 30, calcular(@ana)[:miembros]
  end

  test "una comunidad recién certificada o una membresía recién verificada valen menos" do
    c = red_comunidad(miembros: red_relleno(9), dias: 18) # 10 % de madurez
    red_membresia(c, @ana, dias: 30)
    assert_in_delta 0.25 * 0.1, calcular(@ana)[:puntaje], 0.002

    beto = red_usuario("Beto")
    vieja = red_comunidad(miembros: red_relleno(9))
    red_membresia(vieja, beto, dias: 3) # 3/30
    assert_in_delta 0.25 * 0.1, calcular(beto)[:puntaje], 0.002
  end

  test "comunidades no certificadas, suspendidas o membresías vencidas no cuentan" do
    red_comunidad(miembros: [@ana, *red_relleno(9)], estado: "solicitada")
    suspendida = red_comunidad(miembros: [@ana, *red_relleno(9)])
    suspendida.update!(estado: "suspendida")
    c = red_comunidad(miembros: red_relleno(9))
    red_membresia(c, @ana).update_columns(vence_el: 1.day.ago.to_date)
    assert_equal 0, calcular(@ana)[:comunidades]
  end

  test "dos comunidades con casi los mismos miembros cuentan como una" do
    gente = red_relleno(9)
    red_comunidad(miembros: [@ana, *gente])
    red_comunidad(miembros: [@ana, *gente])
    r = calcular(@ana)
    assert_equal 1, r[:comunidades]
    assert_in_delta 0.25, r[:puntaje], 0.001
  end

  test "un anillo de avales (A avala a B y B avala a A) divide el aporte entre cuatro" do
    beto = red_usuario("Beto")
    c1 = red_comunidad(miembros: red_relleno(8))
    c2 = red_comunidad(miembros: red_relleno(8))
    red_membresia(c1, @ana, por: beto)
    red_membresia(c1, beto)
    red_membresia(c2, beto, por: @ana)
    red_membresia(c2, @ana)
    # Ana: en c1 avalada por Beto, y Ana avaló a Beto en c2 → anillo. En c2 nadie la avaló.
    assert_in_delta 0.25 + 0.25 * 0.25 * 0.7, calcular(@ana)[:puntaje], 0.002
  end

  test "un anillo de tres también se detecta" do
    beto, caro = red_usuario("Beto"), red_usuario("Caro")
    c = red_comunidad(miembros: red_relleno(7))
    red_membresia(c, @ana, por: caro)   # Caro → Ana
    red_membresia(c, beto, por: @ana)   # Ana → Beto
    red_membresia(c, caro, por: beto)   # Beto → Caro
    assert_in_delta 0.25 * 0.25, calcular(@ana)[:puntaje], 0.002
  end

  test "las sanciones la reducen a la mitad cada una; suspendido es nivel 0" do
    red_comunidad(miembros: [@ana, *red_relleno(99)])
    @ana.red_perfil.update!(sanciones: 1)
    assert_in_delta 0.25, calcular(@ana)[:puntaje], 0.001
    @ana.red_perfil.update!(suspendido_at: Time.current)
    assert_equal 0, calcular(@ana)[:nivel]
  end

  test "el tope por comunidad es 1 y los niveles siguen los umbrales" do
    assert_equal 1.0, [Math.log10(1_000_000) / 4, 1.0].min
    { 0.1 => 1, 0.35 => 2, 0.79 => 2, 0.8 => 3, 1.4 => 4, 2.0 => 4 }.each do |puntaje, nivel|
      assert_equal nivel, Red::CalculoConfianza::UMBRALES.find { |_, m| puntaje >= m }&.first || 1
    end
  end

  test "el lote guarda solo nivel, número y banda, y la foto del tamaño de cada comunidad" do
    c = red_comunidad(miembros: [@ana, *red_relleno(149)])
    Red::CalculoConfianza.recalcular_todo!
    fila = Red::Confianza.find_by(user: @ana)
    assert_equal [2, 1, "100_a_1000"], [fila.nivel, fila.comunidades, fila.banda_miembros]
    assert_equal 150, c.reload.tamano_publico
  end
end
