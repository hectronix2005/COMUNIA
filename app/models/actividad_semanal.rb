# Fase 4 del plan de engagement (3-nov-2026): por comunidad y por semana (de lunes a domingo), cuántos miembros
# entraron y cuántos participaron, sobre los miembros activos de hoy. La meta es que entre el 20 % cada semana; el
# 3-nov-2026 eran 5 de 51. Lo pinta /rastreo.
#
# «Entró» cuenta a quien hizo alguna petición bajo /t/<slug> de la comunidad (o de uno de sus grupos), según el
# rastreo de Ahoy, que empezó el 1-nov-2026: las semanas anteriores salen sin dato. «Participó» cuenta a quien
# publicó, comentó, dio me gusta, escribió en el chat, votó una encuesta, respondió a un evento, o pidió, ofreció o
# respondió en «Pido / ofrezco». No cuenta a quienes no cuenta el rastreo (ResumenRastreo.sin_contar) ni la
# comunidad de demostración.
class ActividadSemanal
  SEMANAS = 4
  META = 0.20

  Semana = Data.define(:inicio, :entraron, :participaron) do
    def fin = inicio.end_of_week
    def en_curso? = Time.current.between?(inicio, fin)
  end

  Fila = Data.define(:comunidad, :miembros, :semanas) do
    def actual = semanas.first
    def porcentaje(cifra) = miembros.zero? || cifra.nil? ? nil : (100.0 * cifra / miembros).round
    def en_meta? = actual.entraron.to_i >= (ActividadSemanal::META * miembros).ceil && miembros.positive?
  end

  def self.filas(ahora: Time.current)
    new(ahora:).filas
  end

  def initialize(ahora: Time.current)
    @ahora = ahora
  end

  def inicios = @inicios ||= (0...SEMANAS).map { (@ahora - _1.weeks).beginning_of_week }

  def filas
    Logia.tenants_raiz.where.not(slug: Demo::SLUG).includes(:logias).order(:nombre).filter_map do |comunidad|
      ids = [comunidad.id, *comunidad.logias.map(&:id)]
      miembros = Miembro.where(logia_id: ids).activos.where.not(user_id: ResumenRastreo.sin_contar).distinct.pluck(:user_id).compact
      next if miembros.empty?

      slugs = [comunidad.slug, *comunidad.logias.map(&:slug)].compact
      entradas = por_semana(entradas(miembros, slugs))
      participaciones = por_semana(participaciones(miembros, ids))
      semanas = inicios.map do |inicio|
        entraron = inicio.end_of_week < rastreo_desde ? nil : entradas[inicio]&.size.to_i
        Semana.new(inicio:, entraron:, participaron: participaciones[inicio]&.size.to_i)
      end
      Fila.new(comunidad:, miembros: miembros.size, semanas:)
    end
  end

  private

  def rango = inicios.last..@ahora

  # Desde cuándo hay rastreo; antes no se sabe quién entró.
  def rastreo_desde = @rastreo_desde ||= Ahoy::Visit.minimum(:started_at) || @ahora

  # {inicio de semana => Set de user_id}, a partir de pares [user_id, momento].
  def por_semana(pares)
    pares.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(user_id, momento), acc|
      acc[momento.beginning_of_week] << user_id
    end
  end

  def entradas(miembros, slugs)
    Ahoy::Event.joins(:visit).where(name: "Petición", time: rango, ahoy_visits: { user_id: miembros })
               .where("split_part(ahoy_events.properties->>'ruta', '/', 2) = 't'")
               .where("split_part(ahoy_events.properties->>'ruta', '/', 3) IN (?)", slugs)
               .pluck("ahoy_visits.user_id", "ahoy_events.time")
  end

  def participaciones(miembros, ids)
    en = { user_id: miembros, created_at: rango }
    publicaciones = Publicacion.where(logia_id: ids)
    encuestas = Encuesta.where(logia_id: ids)
    favores = Favor.where(logia_id: ids)
    [
      publicaciones.where(en),
      PublicacionComentario.where(publicacion: publicaciones).where(en),
      PublicacionLike.where(publicacion: publicaciones).where(en),
      ChatMensaje.where(logia_id: ids).where(en),
      EncuestaVoto.where(encuesta_opcion: EncuestaOpcion.where(encuesta: encuestas)).where(en),
      EventoConfirmacion.where(calendario_evento: CalendarioEvento.where(logia_id: ids)).where(en),
      favores.where(en),
      FavorRespuesta.where(favor: favores).where(en)
    ].flat_map { _1.pluck(:user_id, :created_at) }
  end
end
