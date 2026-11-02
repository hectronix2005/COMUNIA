# Panel del rastreo de pruebas (config/initializers/ahoy.rb): quién entró, hasta dónde llegó, cuánto estuvo
# en cada vista y qué errores tuvo. Solo para el superadmin en el panel de plataforma, como /errores.
class RastreoController < ApplicationController
  SEGUNDOS = Arel.sql("(ahoy_events.properties->>'segundos_visible')::int")

  before_action do
    redirect_to root_path, alert: "Acceso exclusivo al administrador de plataforma." unless platform_admin_context?
  end

  def index
    visitas = Ahoy::Visit.where.not(user_id: nil).group(:user_id)
    eventos = Ahoy::Event.joins(:visit).where.not(ahoy_visits: { user_id: nil }).group("ahoy_visits.user_id")
    @numero_visitas = visitas.count
    @ultima = visitas.maximum(:started_at)
    @eventos = eventos.count
    @segundos = eventos.where(name: "Tiempo en vista").sum(SEGUNDOS)
    @errores = eventos.merge(Ahoy::Event.errores).count
    @ultimo_evento = eventos.maximum(:time)
    @personas = User.where(id: @numero_visitas.keys).index_by(&:id)
    @orden = @numero_visitas.keys.sort_by { |id| @ultimo_evento[id] || @ultima[id] }.reverse
    @anonimas = Ahoy::Visit.where(user_id: nil).order(started_at: :desc).limit(50)
    @eventos_anonimas = Ahoy::Event.where(visit_id: @anonimas.map(&:id)).group(:visit_id).count
  end

  def persona
    @persona = User.find(params[:id])
    @visitas = Ahoy::Visit.where(user_id: @persona.id).order(started_at: :desc).limit(30).includes(:events)
  end

  def visita
    @visita = Ahoy::Visit.find(params[:id])
    return redirect_to rastreo_persona_path(@visita.user_id, anchor: "visita-#{@visita.id}") if @visita.user_id
    @visitas = [@visita]
    render :persona
  end
end
