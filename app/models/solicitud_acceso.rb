# Alguien pide entrar a una comunidad con el código que le dio un administrador y una prueba de que
# pertenece a ella. Su cuenta se crea al pedirlo (Devise, en espera: no puede entrar) y un administrador
# la aprueba enlazándola con una ficha que aún no tiene acceso, o creándole una ficha nueva.
class SolicitudAcceso < ApplicationRecord
  self.table_name = "solicitudes_acceso"

  # Contra el abuso del formulario público: con tantas pendientes, la comunidad no recibe más.
  MAX_PENDIENTES = 50

  enum :estado, { pendiente: "pendiente", aprobada: "aprobada", rechazada: "rechazada" }

  belongs_to :logia
  belongs_to :user, optional: true
  belongs_to :decidida_por, class_name: "User", optional: true
  belongs_to :miembro, optional: true

  validates :nombre, :apellido, presence: true, length: { maximum: 60 }
  validates :email, presence: true, length: { maximum: 120 }
  validates :prueba, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :motivo, length: { maximum: 300 }

  def nombre_completo = "#{nombre} #{apellido}"

  # Fichas a las que se puede dar esta cuenta: activas, de la misma logia, de miembros rasos que nunca han
  # entrado. Quien ya entró perdería su contraseña; un admin no se entrega así, ni una cuenta que es también de
  # otra comunidad (quien pidió acceso aquí entraría en esa).
  def fichas_enlazables
    de_otras = Pertenencia.where.not(organizacion_id: logia.organizacion.id).select(:user_id)
    Miembro.activo.where(logia_id: logia_id).joins(:user)
           .where(users: { last_seen_at: nil, rol: User.rols[:miembro] })
           .where.not(users: { id: de_otras })
           .includes(:user).order("users.apellido", "users.nombre")
  end

  # La cuenta de la ficha recibe el correo y la contraseña que eligió quien pidió acceso (el resumen de
  # Devise, nunca la clave en claro), y la cuenta en espera se borra.
  def aprobar_con_ficha!(miembro, por:)
    transaction do
      lock!
      solicitante = cuenta_en_espera!
      falla!("Esa ficha ya no se puede enlazar") unless fichas_enlazables.exists?(miembro.id)
      destino = miembro.user
      correo, resumen = solicitante.email, solicitante.encrypted_password
      solicitante.destroy!
      destino.update!(email: correo, encrypted_password: resumen, invitation_token: nil, invitation_created_at: nil,
                      invitation_sent_at: nil, failed_attempts: 0, locked_at: nil, unlock_token: nil)
      decidir!(:aprobada, por: por, user: destino, miembro: miembro)
    end
  end

  # Sin ficha previa: la cuenta en espera pasa a ser la de una ficha nueva en esta logia.
  def aprobar_con_ficha_nueva!(cedula:, numero_miembro:, por:)
    transaction do
      lock!
      solicitante = cuenta_en_espera!
      solicitante.update!(espera_aprobacion: false, solo_red: false, logia: logia, rol_ref: Rol.find_by(codigo: "miembro"))
      miembro = Miembro.create!(user: solicitante, logia: logia, cedula: cedula, numero_miembro: numero_miembro, estado: :activo)
      decidir!(:aprobada, por: por, user: solicitante, miembro: miembro)
    end
  end

  def rechazar!(por:, motivo: nil)
    transaction do
      lock!
      falla!("Esta solicitud ya se resolvió") unless pendiente?
      user.destroy! if user&.espera_aprobacion?
      decidir!(:rechazada, por: por, user: nil, motivo: motivo)
    end
  end

  private

  def cuenta_en_espera!
    falla!("Esta solicitud ya se resolvió o su cuenta ya no existe") unless pendiente? && user&.espera_aprobacion?
    user
  end

  def falla!(mensaje)
    errors.add(:base, mensaje)
    raise ActiveRecord::RecordInvalid, self
  end

  def decidir!(estado, por:, **attrs)
    update!(estado: estado, decidida_por: por, decidida_at: Time.current, **attrs)
  end
end
