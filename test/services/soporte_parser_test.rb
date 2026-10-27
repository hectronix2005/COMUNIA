require "test_helper"

class SoporteParserTest < ActiveSupport::TestCase
  setup do
    @parser = SoporteParser.new(nil)
  end

  def monto(texto) = @parser.send(:extraer_monto, texto)
  def fecha(texto) = @parser.send(:extraer_fecha, texto)

  test "lee montos con puntos de miles y con el formato de Bancolombia en la web" do
    assert_equal 200_000, monto("VALOR $ 200.000")
    assert_equal 400_000, monto("Valor a transferir $400,000.00")
    assert_equal 1_250_000, monto("Total pagado $1.250.000,00")
    assert_equal 75_000, monto("75.000 COP")
  end

  test "tolera una cifra de más que mete el OCR tras los decimales" do
    assert_equal 400_000, monto("Valor a tanstenr $400,000.000.")
  end

  test "no confunde una IP ni el costo de la transacción con el monto" do
    texto = <<~TXT
      Dirección IP 161.193.4.116
      Costo de la transacción (IVA incluido) $10,532.00
    TXT
    assert_nil monto(texto)
    assert_equal 400_000, monto("#{texto}Valor a transferir $400,000.00")
  end

  test "lee fechas con el mes abreviado" do
    assert_equal "2026-03-11", fecha("11 mar, 2026--6:20:33 PM")
    assert_equal "2026-03-11", fecha("MAR 11 2026 15:39:56")
    assert_equal "2026-03-16", fecha("16 de marzo de 2026")
    assert_equal "2026-03-16", fecha("Fecha de transacción 16/03/2026")
  end
end
