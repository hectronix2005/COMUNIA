require "test_helper"

# Fase 5: lote diario (confianza, purga de contactos externos, avisos) y alertas de comunidades infladas.
class Red::MantenimientoTest < ActiveSupport::TestCase
  include RedPrueba

  test "el lote diario recalcula la foto de confianza y el tamaño público de cada comunidad" do
    ana = red_usuario("Ana")
    club = red_comunidad(miembros: [ana] + red_relleno(99))
    Red::CalculoConfianza.guardar!(ana)
    assert_equal 0, club.reload.tamano_publico
    Red::MantenimientoDiarioJob.perform_now
    assert_equal 100, club.reload.tamano_publico
    foto = Red::Confianza.find_by(user_id: ana.id)
    assert_equal 1, foto.comunidades
    assert_equal "100_a_1000", foto.banda_miembros
    assert foto.nivel >= 2
  end

  test "un cambio de comunidades no se ve hasta el lote siguiente" do
    ana = red_usuario("Ana")
    Red::MantenimientoDiarioJob.perform_now
    assert_equal 0, Red::Confianza.find_by(user_id: ana.id).comunidades
    red_comunidad(miembros: [ana] + red_relleno(9))
    assert_equal 0, Red::Confianza.find_by(user_id: ana.id).comunidades
    Red::MantenimientoDiarioJob.perform_now
    assert_equal 1, Red::Confianza.find_by(user_id: ana.id).comunidades
  end

  test "el contacto de quien escribió sin cuenta se borra a los 90 días" do
    ana = red_usuario("Ana")
    vieja = Red::Conversacion.create!(destinatario: ana, nombre_externo: "Luis", contacto_externo: "luis@correo.co", created_at: 91.days.ago)
    nueva = Red::Conversacion.create!(destinatario: ana, nombre_externo: "Eva", contacto_externo: "eva@correo.co")
    Red::MantenimientoDiarioJob.perform_now
    assert_nil vieja.reload.contacto_externo
    assert_equal "eva@correo.co", nueva.reload.contacto_externo
  end

  test "avisa de publicaciones y membresías por vencer" do
    ana = red_usuario("Ana")
    club = red_comunidad("Club Vence", miembros: [ana])
    club.membresias.find_by(user: ana).update!(vence_el: 15.days.from_now.to_date)
    red_publicacion(ana, vence_el: 3.days.from_now.to_date)
    Red::MantenimientoDiarioJob.perform_now
    titulos = ana.notificaciones.pluck(:titulo)
    assert_includes titulos, "Tu publicación vence en 3 días"
    assert_includes titulos, "Tu membresía en Club Vence vence en 15 días"
  end

  test "alerta: una comunidad que se infla de golpe o un verificador que aprueba en masa" do
    verificador = red_usuario("Vero")
    club = red_comunidad("Club Inflado", miembros: [verificador] + red_relleno(5), dias: 200)
    red_relleno(30).each { |u| red_membresia(club, u, dias: 0, por: verificador) }
    alertas = Red::Alertas.crecimiento_anomalo
    textos = alertas.select { _1[:comunidad] == club }.map { _1[:texto] }
    assert textos.any? { _1.include?("altas en 7 días") }, textos.inspect
    assert textos.any? { _1.include?("un verificador aprobó 30") }, textos.inspect

    estable = red_comunidad("Club Estable", miembros: red_relleno(40), dias: 400)
    red_relleno(3).each { |u| red_membresia(estable, u, dias: 1) }
    assert_empty Red::Alertas.crecimiento_anomalo.select { _1[:comunidad] == estable }
  end

  test "inflar una comunidad con altas de hoy no sube la confianza hoy (rampa de 30 días)" do
    ana = red_usuario("Ana")
    club = red_comunidad(miembros: [ana] + red_relleno(9), dias: 365)
    antes = Red::CalculoConfianza.calcular(ana)[:puntaje]
    red_relleno(90).each_slice(200) do |grupo|
      Red::Membresia.insert_all(grupo.map { { comunidad_id: club.id, user_id: _1.id, estado: "verificada", rol: "miembro",
                                             verificada_at: Time.current, vence_el: 1.year.from_now.to_date,
                                             created_at: Time.current, updated_at: Time.current } })
    end
    despues = Red::CalculoConfianza.calcular(ana)[:puntaje]
    # El tamaño sube (de 10 a 100) y se nota: la rampa protege a quienes acaban de entrar, no a la comunidad.
    assert despues > antes
    nuevo = Red::Membresia.where(comunidad: club).order(:id).last.user
    red_perfil(nuevo)
    assert_equal 0.0, Red::CalculoConfianza.calcular(nuevo)[:puntaje]
  end
end
