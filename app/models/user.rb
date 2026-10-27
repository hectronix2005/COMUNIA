class User < ApplicationRecord
  devise :invitable, :database_authenticatable, :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable

  # Los correos de Devise salen en segundo plano: un fallo del SMTP no llega a la página, y la
  # respuesta tarda lo mismo exista o no la cuenta.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  enum :rol, { miembro: 0, admin_logia: 1, super_admin: 2 }
  # El rol que cuenta es rol_ref: de él salen los permisos y es el que cambia la ficha del miembro. El enum
  # se copia de él para que no se desincronicen (en producción llegaron a no coincidir en 5 usuarios).
  ROL_POR_CODIGO = { "super_admin" => "super_admin", "admin_logia" => "admin_logia" }.freeze

  belongs_to :logia, optional: true
  belongs_to :rol_ref, class_name: "Rol", optional: true
  has_one_attached :avatar
  has_one :miembro, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :notificaciones, class_name: "Notificacion", dependent: :destroy
  has_many :evento_confirmaciones, dependent: :destroy
  has_many :encuesta_votos, dependent: :destroy
  has_many :publicaciones, dependent: :destroy
  has_many :publicacion_likes, dependent: :destroy
  has_many :publicacion_comentarios, dependent: :destroy
  has_many :negocio_favoritos, dependent: :destroy
  has_many :negocio_anuncios_favoritos, through: :negocio_favoritos, source: :negocio_anuncio

  # Red de comunidades certificadas (app/models/red.rb)
  has_one :red_perfil, class_name: "Red::Perfil", dependent: :destroy
  has_one :red_confianza, class_name: "Red::Confianza", dependent: :delete
  has_many :red_membresias, class_name: "Red::Membresia", dependent: :destroy
  has_many :red_publicaciones, class_name: "Red::Publicacion", dependent: :destroy

  validates :nombre, :apellido, presence: true
  validates :logia, presence: true, unless: -> { super_admin? || solo_red? }
  # Las cuentas de la red se registran solas, y quien acepta una invitación elige la suya: contraseña más
  # larga que las que crea un admin.
  validates :password, length: { minimum: 10 }, if: -> { (solo_red? || accepting_invitation?) && password.present? }
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9]+\z/, message: "solo letras minúsculas y números" },
                       if: -> { username.present? }

  before_validation :generate_username, on: :create, if: -> { username.blank? }
  before_validation -> { self.rol = ROL_POR_CODIGO.fetch(rol_ref.codigo, "miembro") }, if: :rol_ref

  def self.find_for_database_authentication(warden_conditions)
    login = warden_conditions[:email].to_s.strip
    return nil if login.blank?
    # Se entra con el usuario o con el correo (único en la tabla); las cuentas de la red no tienen usuario.
    return find_by(email: login.downcase) if login.include?("@")
    find_by("LOWER(username) = ?", login.downcase)
  end

  scope :admins, -> { where(rol: [:admin_logia, :super_admin]) }
  scope :por_logia, ->(logia_id) { where(logia_id: logia_id) }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at < 2.minutes.ago
  end

  # Estado del acceso a la app, para la ficha y la lista de miembros.
  def acceso
    if invitation_token.present? && invitation_created_at
      valid_invitation? ? :invitado : :invitacion_caducada
    elsif last_seen_at
      :entro
    else
      :nunca
    end
  end

  def online?
    last_seen_at.present? && last_seen_at > 5.minutes.ago
  end

  # Suscripción al calendario desde el teléfono: su app de calendario pide la dirección cada pocas horas, sin
  # sesión. La dirección lleva una semilla aleatoria y su firma con la clave de la app, así que la base de datos
  # sola no basta para fabricarla; cambiar la semilla anula la dirección anterior.
  def calendario_token
    calendario_semilla && calendario_semilla + User.firma_calendario(calendario_semilla)
  end

  def renovar_calendario! = update_column(:calendario_semilla, SecureRandom.hex(12))
  def anular_calendario!  = update_column(:calendario_semilla, nil)

  def self.por_token_de_calendario(token)
    return unless token.is_a?(String) && token.match?(/\A\h{64}\z/)
    user = find_by(calendario_semilla: token[0, 24]) or return
    user if ActiveSupport::SecurityUtils.secure_compare(token[24..], firma_calendario(user.calendario_semilla))
  end

  def self.firma_calendario(semilla)
    clave = Rails.application.key_generator.generate_key("calendario-suscripcion")
    OpenSSL::HMAC.hexdigest("SHA256", clave, semilla)[0, 40]
  end

  # Primer nombre + primer apellido ("Hector Andrey Neira Duque" → "Hector Neira")
  def nombre_corto
    primer_nombre   = nombre.to_s.strip.split(/\s+/).first
    primer_apellido = apellido.to_s.strip.split(/\s+/).first
    [primer_nombre, primer_apellido].compact.join(" ").presence || nombre_completo
  end

  # Nombre que se muestra a otros usuarios en el chat. Permite que cada
  # miembro personalice cómo se le ve, con fallback a nombre_corto.
  def nombre_chat
    nombre_visible.presence || nombre_corto
  end

  def tiene_permiso?(recurso, accion)
    return true if rol_ref&.codigo == "super_admin"
    rol_ref&.tiene_permiso?(recurso, accion) || false
  end

  # true si el usuario tiene el cargo (vigente) indicado — por nombre,
  # o si es admin_logia / super_admin (bypass).
  def tiene_cargo?(nombre_cargo)
    return true if rol_ref&.es_super_admin?
    return true if rol_ref&.codigo == "admin_logia"
    m = miembro
    return false unless m
    m.miembro_cargos.vigentes.joins(:cargo)
      .where("LOWER(cargos.nombre) = ?", nombre_cargo.to_s.downcase)
      .exists?
  end

  def nombre_rol
    rol_ref&.nombre || rol.to_s.humanize
  end

  def scope_propia_logia?
    rol_ref.present? && !rol_ref.es_super_admin? && logia_id.present?
  end

  # Returns the array of logia IDs this user can access.
  # - super_admin: nil (unrestricted)
  # - admin of root tenant: tenant_id + all child logia ids
  # - admin of sub-logia: just their logia_id
  def logia_ids_accesibles
    return nil unless scope_propia_logia?
    logia = self.logia
    return [logia_id] unless logia
    if logia.tenant_id.nil?
      # Assigned to a root tenant → access all its sub-logias too
      [logia.id] + logia.logias.pluck(:id)
    else
      [logia_id]
    end
  end

  def admin_tenant?
    admin_logia? && logia&.tenant_id.nil?
  end

  private

  def generate_username
    base = build_username_base
    candidate = base
    suffix = 2
    while User.where("LOWER(username) = ?", candidate.downcase).exists?
      candidate = "#{base}#{suffix}"
      suffix += 1
    end
    self.username = candidate
  end

  def build_username_base
    n = transliterate_username(nombre.to_s.strip)
    a = transliterate_username(apellido.to_s.strip.split.first.to_s)
    "#{n[0]}#{a}".downcase.gsub(/[^a-z0-9]/, "").presence || "user"
  end

  def transliterate_username(str)
    str.unicode_normalize(:nfd).encode("ASCII", invalid: :replace, undef: :replace, replace: "")
  rescue
    str.tr("áàäâãÁÀÄÂÃ", "aaaaa" * 2)
       .tr("éèëêÉÈËÊ", "eeee" * 2)
       .tr("íìïîÍÌÏÎ", "iiii" * 2)
       .tr("óòöôõÓÒÖÔÕ", "ooooo" * 2)
       .tr("úùüûÚÙÜÛ", "uuuu" * 2)
       .tr("ñÑ", "nn")
  end
end
