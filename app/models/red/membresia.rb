module Red
  # Pertenencia de una persona a una comunidad. La pide la persona con su evidencia y la aprueba un
  # verificador de ESA comunidad, que nunca ve las demás comunidades de quien la pide.
  class Membresia < ApplicationRecord
    ESTADOS = %w[solicitada verificada rechazada revocada retirada].freeze
    ROLES = { "miembro" => "Miembro", "verificador" => "Verificador", "administrador" => "Administrador" }.freeze
    VIGENCIA = 1.year

    belongs_to :comunidad, class_name: "Red::Comunidad"
    belongs_to :user
    belongs_to :verificada_por, class_name: "User", optional: true

    validates :estado, inclusion: { in: ESTADOS }
    validates :rol, inclusion: { in: ROLES.keys }
    validates :evidencia, length: { maximum: 1000 }
    validates :motivo, length: { maximum: 500 }
    validates :user_id, uniqueness: { scope: :comunidad_id }

    scope :verificadas_y_vigentes, -> { where(estado: "verificada").where("red_membresias.vence_el IS NULL OR red_membresias.vence_el >= ?", Date.current) }
    # Las que cuentan: verificadas, vigentes y en una comunidad certificada.
    scope :vigentes, -> { verificadas_y_vigentes.joins(:comunidad).merge(Comunidad.certificadas) }
    scope :pendientes, -> { where(estado: "solicitada") }

    after_commit -> { comunidad.recontar! if comunidad && !comunidad.destroyed? }, on: %i[create update destroy]

    def verificada? = estado == "verificada"

    def rol_texto = ROLES.fetch(rol)

    def vencida? = vence_el.present? && vence_el < Date.current

    # Aprueba la solicitud. Nadie se aprueba a sí mismo.
    def verificar!(por:)
      raise ArgumentError, "Nadie puede avalarse a sí mismo" if por.id == user_id && !Red.moderador?(por)
      update!(estado: "verificada", verificada_por: por, verificada_at: Time.current,
              vence_el: VIGENCIA.from_now.to_date, motivo: nil)
    end

    def renovar!(por:)
      update!(vence_el: VIGENCIA.from_now.to_date, verificada_por: por)
    end

    def rechazar!(motivo:) = update!(estado: "rechazada", motivo: motivo.to_s.strip.presence)

    def revocar!(motivo:) = update!(estado: "revocada", motivo: motivo.to_s.strip.presence || "Sin motivo", rol: "miembro")
  end
end
