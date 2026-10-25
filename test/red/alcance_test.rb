require "test_helper"

# Visibilidad por alcance (Red::ConAlcance) de publicaciones y perfiles.
class Red::AlcanceTest < ActiveSupport::TestCase
  include RedPrueba

  setup do
    @ana, @beto, @caro, @dani = %w[Ana Beto Caro Dani].map { red_usuario(_1) }
    @club = red_comunidad("Club", miembros: [@ana, @beto])
    @uni = red_comunidad("Universidad", miembros: [@ana, @caro])
    # Dani no está en ninguna.
  end

  def ve?(viewer, pub) = Red::Publicacion.tablon_para(viewer).exists?(pub.id)

  test "público: lo ve todo el mundo, también sin cuenta" do
    p = red_publicacion(@ana, alcance: "publico")
    assert [nil, @beto, @caro, @dani].all? { ve?(_1, p) }
  end

  test "mis comunidades: solo quien comparte alguna con el autor" do
    p = red_publicacion(@ana, alcance: "mis_comunidades")
    assert ve?(@beto, p)
    assert ve?(@caro, p)
    assert_not ve?(@dani, p)
    assert_not ve?(nil, p)
    assert ve?(@ana, p), "el autor ve lo suyo"
  end

  test "elegidas: solo las comunidades elegidas, y solo entre las del autor" do
    ajena = red_comunidad("Ajena", miembros: [@dani])
    p = Red::Publicacion.new(user: @ana, intencion: "necesito", categoria: "empleo", titulo: "Busco trabajo",
                             descripcion: "Contadora con 5 años de experiencia.", alcance: "elegidas")
    p.comunidades_elegidas = [@club.id, ajena.id]
    p.save!
    assert_equal [@club.id], p.reload.comunidad_ids_elegidas, "la comunidad ajena se descarta en silencio"
    assert ve?(@beto, p)
    assert_not ve?(@caro, p), "la universidad no fue elegida"
    assert_not ve?(@dani, p), "elegir una comunidad ajena no la abre"
  end

  test "elegidas sin ninguna comunidad propia no valida" do
    p = Red::Publicacion.new(user: @dani, intencion: "necesito", categoria: "empleo", titulo: "Busco trabajo",
                             descripcion: "Contadora con 5 años de experiencia.", alcance: "elegidas")
    p.comunidades_elegidas = [@club.id]
    assert_not p.valid?
  end

  test "si el autor deja la comunidad, lo que era para ella se deja de ver" do
    p = red_publicacion(@ana, alcance: "mis_comunidades")
    @club.membresias.find_by(user: @ana).revocar!(motivo: "salió")
    assert_not ve?(@beto, p)
    assert ve?(@caro, p)
  end

  test "lo público de una cuenta en cuarentena espera, salvo para quien comparte comunidad" do
    @ana.red_perfil.update!(cuarentena_hasta: 2.days.from_now)
    p = red_publicacion(@ana, alcance: "publico", publica_desde: 2.days.from_now)
    assert_not ve?(nil, p)
    assert_not ve?(@dani, p)
    assert ve?(@beto, p)
  end

  test "lo de un perfil suspendido, en revisión o vencido no se ve" do
    p = red_publicacion(@ana)
    p.update!(estado: "en_revision")
    assert_not ve?(@beto, p)
    p.update!(estado: "activa")
    p.update_columns(vence_el: 1.day.ago.to_date)
    assert_not ve?(@beto, p)
    p.update_columns(vence_el: 1.day.from_now.to_date)
    @ana.red_perfil.update!(suspendido_at: Time.current)
    assert_not ve?(@beto, p)
  end

  test "perfiles: el mismo alcance" do
    @ana.red_perfil.update!(alcance: "mis_comunidades")
    assert Red::Perfil.visibles_para(@beto).exists?(@ana.red_perfil.id)
    assert_not Red::Perfil.visibles_para(@dani).exists?(@ana.red_perfil.id)
    assert_not Red::Perfil.visibles_para(nil).exists?(@ana.red_perfil.id)
  end
end
