module Red
  # Una comunidad con algo en común comprobable. La certifica la plataforma tras revisar la
  # evidencia de que existe y el método con que se comprobará a cada miembro.
  class Comunidad < ApplicationRecord
    TIPOS = {
      "club" => "Club", "universidad" => "Universidad", "colegio" => "Colegio",
      "barrio" => "Barrio o conjunto residencial", "empresa" => "Empresa", "gremio" => "Gremio o asociación",
      "logia" => "Logia", "otro" => "Otro vínculo comprobable"
    }.freeze

    METODOS = {
      "documento" => "Carné, diploma o certificado que revisa un verificador",
      "correo_institucional" => "Correo con el dominio de la comunidad",
      "presencial" => "Un verificador conoce a la persona en persona",
      "registro_oficial" => "Registro oficial (los miembros activos de una logia de COMUNIA)"
    }.freeze

    ESTADOS = %w[solicitada certificada rechazada suspendida revocada].freeze

    # Por debajo de este tamaño una comunidad no aporta confianza (Red::CalculoConfianza).
    MINIMO_MIEMBROS = 5

    has_secure_token :token, length: 24
    has_many :membresias, class_name: "Red::Membresia", dependent: :destroy
    has_many :alcances, class_name: "Red::Alcance", dependent: :delete_all
    belongs_to :logia, optional: true
    belongs_to :solicitada_por, class_name: "User", optional: true
    belongs_to :revisada_por, class_name: "User", optional: true

    validates :nombre, presence: true, length: { in: 3..80 }, uniqueness: { case_sensitive: false }
    validates :tipo_vinculo, inclusion: { in: TIPOS.keys }
    validates :metodo_verificacion, inclusion: { in: METODOS.keys }
    validates :estado, inclusion: { in: ESTADOS }
    validates :criterio, presence: true, length: { in: 10..500 }
    validates :descripcion, length: { maximum: 2000 }
    validates :evidencia, length: { maximum: 2000 }
    validates :ciudad, length: { maximum: 60 }
    validates :motivo_estado, length: { maximum: 500 }
    validates :dominio_correo, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/ }, allow_blank: true
    validates :dominio_correo, presence: true, if: -> { metodo_verificacion == "correo_institucional" }

    scope :certificadas, -> { where(estado: "certificada") }
    scope :pendientes, -> { where(estado: "solicitada") }

    def to_param = token

    def certificada? = estado == "certificada"

    def tipo_texto = TIPOS.fetch(tipo_vinculo)

    def metodo_texto = METODOS.fetch(metodo_verificacion)

    def banda_tamano = Red.banda(miembros_count)

    def certificar!(por:)
      transaction do
        update!(estado: "certificada", certificada_at: certificada_at || Time.current, revisada_por: por, motivo_estado: nil)
        # Quien la pidió queda como su primer administrador, ya verificado.
        if solicitada_por && (m = membresias.find_by(user: solicitada_por))
          m.update!(estado: "verificada", rol: "administrador", verificada_por: por, verificada_at: Time.current, vence_el: 1.year.from_now.to_date)
        end
        recontar!
      end
    end

    def cambiar_estado!(nuevo, por:, motivo:)
      raise ArgumentError, "estado inválido" unless nuevo.in?(%w[rechazada suspendida revocada])
      update!(estado: nuevo, revisada_por: por, motivo_estado: motivo.to_s.strip.presence || "Sin motivo")
    end

    def recontar!
      update_column(:miembros_count, membresias.verificadas_y_vigentes.count)
    end

    # ¿Puede `user` aprobar membresías aquí? (verificador o administrador, o la plataforma).
    def verificador?(user)
      return true if Red.moderador?(user)
      membresias.verificadas_y_vigentes.where(user_id: user&.id, rol: %w[verificador administrador]).exists?
    end

    def administrador?(user)
      return true if Red.moderador?(user)
      membresias.verificadas_y_vigentes.where(user_id: user&.id, rol: "administrador").exists?
    end

    # Correo institucional: el dominio del correo de la cuenta tiene que ser el de la comunidad.
    def correo_admitido?(email)
      dominio_correo.present? && email.to_s.downcase.end_with?("@#{dominio_correo}", ".#{dominio_correo}")
    end
  end
end
