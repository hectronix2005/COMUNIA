module Red
  # Perfil de una persona en la red: quién es, qué sabe hacer, su hoja de vida y quién puede verlo.
  # El teléfono y el correo de contacto solo salen cuando ella los comparte en una conversación.
  class Perfil < ApplicationRecord
    include ConAlcance

    CUARENTENA = 72.hours
    SANCIONES_PARA_SUSPENDER = 3

    has_secure_token :token, length: 24
    belongs_to :user
    has_one_attached :hoja_de_vida

    normalizes :nombre_publico, :titular, :ciudad, with: ->(v) { v.to_s.squish.presence }
    normalizes :contacto_correo, with: ->(v) { v.to_s.strip.downcase.presence }
    normalizes :contacto_telefono, with: ->(v) { v.to_s.gsub(/[^\d+]/, "").presence }

    validates :nombre_publico, presence: true, length: { in: 2..60 }
    validates :titular, length: { maximum: 120 }
    validates :bio, length: { maximum: 2000 }
    validates :ciudad, length: { maximum: 60 }
    validates :habilidades, length: { maximum: 500 }
    validates :contacto_correo, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 120 }, allow_blank: true
    validates :contacto_telefono, format: { with: /\A\+?\d{7,15}\z/ }, allow_blank: true
    validates :politica_version, :acepto_tratamiento_at, :cuarentena_hasta, presence: true
    validate :hoja_de_vida_pdf

    before_validation on: :create do
      self.cuarentena_hasta ||= CUARENTENA.from_now
    end

    scope :activos, -> { where(suspendido_at: nil) }

    def to_param = token

    def suspendido? = suspendido_at.present?

    def en_cuarentena? = cuarentena_hasta > Time.current

    def onboarding_completo? = onboarding_completado_at.present?

    # Solo aparece en la búsqueda sin cuenta quien lo eligió (visible_publico) y con alcance público.
    def self.buscables_sin_cuenta = activos.where(visible_publico: true, alcance: "publico")

    def sancionar!
      increment!(:sanciones)
      update_column(:suspendido_at, Time.current) if sanciones >= SANCIONES_PARA_SUSPENDER
    end

    private

    def hoja_de_vida_pdf
      return unless hoja_de_vida.attached?
      errors.add(:hoja_de_vida, "debe ser un PDF") unless hoja_de_vida.blob.content_type == "application/pdf"
      errors.add(:hoja_de_vida, "no puede pasar de 5 MB") if hoja_de_vida.blob.byte_size > 5.megabytes
    end
  end
end
