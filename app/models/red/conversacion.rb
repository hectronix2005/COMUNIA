module Red
  # Canal intermediado entre quien busca y quien publica. Ninguno ve el teléfono ni el correo del
  # otro hasta que este los comparte. Quien busca sin cuenta deja su propio medio de contacto, que se
  # guarda cifrado y se borra a los 90 días (Red::Limpieza).
  class Conversacion < ApplicationRecord
    ESTADOS = %w[abierta bloqueada cerrada].freeze
    RETENCION_EXTERNA = 90.days

    has_secure_token :token, length: 24
    belongs_to :publicacion, class_name: "Red::Publicacion", optional: true
    belongs_to :iniciador, class_name: "User", optional: true
    belongs_to :destinatario, class_name: "User"
    has_many :mensajes, -> { order(:created_at, :id) }, class_name: "Red::Mensaje", dependent: :delete_all
    has_many :resenas, class_name: "Red::Resena", dependent: :delete_all

    validates :estado, inclusion: { in: ESTADOS }
    validates :nombre_externo, presence: true, length: { in: 2..60 }, if: :externa?
    validate :no_consigo_mismo

    scope :de, ->(user) { where(iniciador_id: user.id).or(where(destinatario_id: user.id)) }

    def to_param = token

    def externa? = iniciador_id.nil?

    def participa?(user) = user && (iniciador_id == user.id || destinatario_id == user.id)

    def otro(user) = iniciador_id == user.id ? destinatario : iniciador

    def contacto_externo = contacto_externo_cif.present? ? Red::Cifra.descifrar(contacto_externo_cif) : nil

    def contacto_externo=(valor)
      self.contacto_externo_cif = valor.present? ? Red::Cifra.cifrar(valor) : nil
    end

    # Reseña verificable: los dos escribieron al menos un mensaje y pasó un día desde el primero.
    def resenable_por?(user)
      return false if externa? || !participa?(user)
      autores = mensajes.reorder(nil).where(tipo: %w[texto contacto_compartido]).distinct.pluck(:user_id)
      primero = mensajes.minimum(:created_at)
      autores.include?(iniciador_id) && autores.include?(destinatario_id) && primero && primero <= 1.day.ago &&
        !resenas.exists?(autor_id: user.id)
    end

    private

    def no_consigo_mismo
      errors.add(:base, "No puedes escribirte a ti mismo") if iniciador_id.present? && iniciador_id == destinatario_id
    end
  end
end
