module Red
  # Lo que una persona necesita u ofrece: trabajo, servicios, productos… con su alcance.
  class Publicacion < ApplicationRecord
    include ConAlcance

    INTENCIONES = { "necesito" => "Necesito", "ofrezco" => "Ofrezco" }.freeze
    CATEGORIAS = {
      "empleo" => "Empleo", "servicios" => "Servicios profesionales", "oficios" => "Oficios y reparaciones",
      "productos" => "Productos", "vivienda" => "Vivienda y arriendo", "formacion" => "Clases y formación",
      "transporte" => "Transporte", "salud" => "Salud y cuidado", "voluntariado" => "Voluntariado y ayuda",
      "otro" => "Otro"
    }.freeze
    MODALIDADES = { "presencial" => "Presencial", "remoto" => "Remoto", "mixto" => "Mixto" }.freeze
    ESTADOS = %w[activa en_revision pausada cerrada retirada].freeze
    VIGENCIA = 30.days

    has_secure_token :token, length: 24
    belongs_to :user
    has_one :perfil, through: :user, source: :red_perfil
    has_many :reportes, as: :objeto, class_name: "Red::Reporte", dependent: :delete_all
    has_many :conversaciones, class_name: "Red::Conversacion", dependent: :nullify

    normalizes :titulo, :ciudad, :precio_texto, with: ->(v) { v.to_s.squish.presence }

    validates :intencion, inclusion: { in: INTENCIONES.keys }
    validates :categoria, inclusion: { in: CATEGORIAS.keys }
    validates :modalidad, inclusion: { in: MODALIDADES.keys }
    validates :estado, inclusion: { in: ESTADOS }
    validates :titulo, presence: true, length: { in: 5..100 }
    validates :descripcion, presence: true, length: { in: 10..3000 }
    validates :ciudad, length: { maximum: 60 }
    validates :precio_texto, length: { maximum: 60 }

    before_validation on: :create do
      self.vence_el ||= VIGENCIA.from_now.to_date
      self.publica_desde ||= Time.current
    end

    scope :vigentes, -> { where(estado: "activa").where("red_publicaciones.vence_el >= ?", Date.current) }

    # Lo que `viewer` puede ver en el tablón o la búsqueda. Lo público espera a que acabe la
    # cuarentena del autor; para quien comparte comunidad con él, no (allí ya lo conocen).
    def self.tablon_para(viewer, comunidad_ids = Red.comunidades_de(viewer))
      espera = ["red_publicaciones.alcance <> 'publico'", "red_publicaciones.publica_desde <= :ahora",
                "red_publicaciones.user_id = :viewer"]
      espera << autor_comparte_sql if comunidad_ids.any?
      vigentes.visibles_para(viewer, comunidad_ids)
              .joins(user: :red_perfil).merge(Perfil.activos)
              .where(sanitize_sql_array(["(#{espera.join(' OR ')})", { ahora: Time.current, viewer: viewer&.id || 0, ids: comunidad_ids }]))
    end

    # Una sola publicación por token, con la misma consulta tanto si no existe como si está oculta.
    def self.visible(token, viewer) = tablon_para(viewer).find_by(token: token.to_s)

    def to_param = token

    def intencion_texto = INTENCIONES.fetch(intencion)

    def categoria_texto = CATEGORIAS.fetch(categoria)

    def modalidad_texto = MODALIDADES.fetch(modalidad)

    def vigente? = estado == "activa" && vence_el >= Date.current

    def renovar! = update!(vence_el: VIGENCIA.from_now.to_date, estado: estado == "cerrada" ? "activa" : estado)
  end
end
