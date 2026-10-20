module Denuncias
  # Cuenta con alias de DENUNCIAPP. NO es un usuario de COMUNIA ni un miembro: es una cuenta aparte,
  # por correo y enlace mágico (devise-passwordless), cuyo correo se guarda cifrado y se busca por
  # HMAC. En el muro solo se ve el alias, que se elige una vez y no cambia.
  class Cuenta < ApplicationRecord
    self.table_name = "denuncias_cuentas"

    ALIAS_VALIDO = /\A[a-z0-9_]{3,20}\z/
    ALIAS_RESERVADOS = %w[admin operador denunciapp policia fiscalia gaula anonimo moderador].freeze
    USO_HMAC = "denunciapp/email".freeze

    devise :magic_link_authenticatable,
           passwordless_login_within: 15.minutes, passwordless_expire_old_tokens_on_sign_in: true

    def devise_mailer = CuentasMailer

    # Correo en claro solo en memoria (para enviar el enlace); en la base va cifrado.
    attr_writer :email
    def email = @email ||= (Cripto.descifrar_b64(email_cif) if email_cif)

    has_many :reportes, foreign_key: :cuenta_id

    def self.normalizar(email) = email.to_s.strip.downcase
    def self.hash_email(email) = Cripto.hmac_hex(USO_HMAC, normalizar(email))

    def self.find_for_authentication(conditions)
      email = conditions.to_h.symbolize_keys[:email]
      email.present? ? find_by(email_hash: hash_email(email))&.tap { _1.email = normalizar(email) } : nil
    end

    # Primer acceso: la cuenta se crea al pedir el enlace (como hacía Auth.js).
    def self.buscar_o_crear(email)
      olvidar_accesos!
      email = normalizar(email)
      return nil unless email.match?(URI::MailTo::EMAIL_REGEXP) && email.size <= 254
      find_for_authentication(email: email) ||
        create!(id: SecureRandom.uuid, email_hash: hash_email(email), email_cif: Cripto.cifrar_b64(email),
                creado_en: Cripto.hora_redondeada).tap { _1.email = email }
    rescue ActiveRecord::RecordNotUnique
      find_for_authentication(email: email)
    end

    # Al entrar con el enlace: correo verificado, y los enlaces anteriores dejan de servir.
    def after_magic_link_authentication
      update_columns(email_verificado: email_verificado || Cripto.hora_redondeada, current_sign_in_at: Time.current)
      self.class.olvidar_accesos!
    end

    # current_sign_in_at es la hora exacta del último acceso: solo hace falta mientras pueda quedar
    # vivo un enlace anterior (15 min). Pasado eso se borra, para no guardar un «visto por última vez».
    def self.olvidar_accesos!
      where(current_sign_in_at: ...passwordless_login_within.ago).update_all(current_sign_in_at: nil)
    end

    # El alias solo se asigna si aún no tiene uno (UPDATE condicionado: no se puede cambiar).
    def asignar_alias(valor)
      limpio = valor.to_s.strip.downcase
      return :invalido unless limpio.match?(ALIAS_VALIDO) && !ALIAS_RESERVADOS.include?(limpio)
      filas = self.class.where(id: id, alias: nil).update_all(alias: limpio)
      filas == 1 ? (self.alias = limpio; :ok) : :ocupado
    rescue ActiveRecord::RecordNotUnique
      :ocupado
    end
  end
end
