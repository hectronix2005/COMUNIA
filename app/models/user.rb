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
  # Una ficha por comunidad (organización) a la que pertenece; la que se usa es la de la comunidad que se mira
  # (#miembro).
  has_many :miembros, dependent: :destroy
  has_many :pertenencias, dependent: :destroy
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

  validates :nombre, presence: true
  # Quien entró con el celular y aún no completa sus datos puede no tener apellido (CompletarDatosController).
  validates :apellido, presence: true, unless: :debe_completar_datos?
  validates :celular, uniqueness: true, format: { with: /\A3\d{9}\z/, message: "debe ser un celular de 10 dígitos" },
                      allow_nil: true
  validates :logia, presence: true, unless: -> { super_admin? || solo_red? }
  # Las cuentas de la red se registran solas, y quien acepta una invitación elige la suya: contraseña más
  # larga que las que crea un admin.
  validates :password, length: { minimum: 10 }, if: -> { (solo_red? || accepting_invitation? || completando_datos) && password.present? }
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9]+\z/, message: "solo letras minúsculas y números" },
                       if: -> { username.present? }

  before_validation :generate_username, on: :create, if: -> { username.blank? }
  # Sin correo se guarda NULL, no "": así varias cuentas con solo celular no chocan en el índice único.
  before_validation { self.email = email.presence }
  before_validation { self.celular = User.normalizar_celular(celular) }
  before_validation -> { self.rol = ROL_POR_CODIGO.fetch(rol_ref.codigo, "miembro") }, if: :rol_ref
  after_save :guardar_pertenencia, if: -> { saved_change_to_logia_id? || saved_change_to_rol_ref_id? }

  # Quien pidió acceso con el código de su comunidad no entra hasta que un administrador lo apruebe.
  def active_for_authentication? = super && !espera_aprobacion?
  def inactive_message = espera_aprobacion? ? :espera_aprobacion : super

  attr_accessor :completando_datos

  # Con celular no hace falta correo: lo pide la pantalla de completar datos.
  def email_required? = celular.blank?

  def self.find_for_database_authentication(warden_conditions)
    login = warden_conditions[:email].to_s.strip
    return nil if login.blank?
    # Se entra con el usuario, el correo o el celular (únicos en la tabla); las cuentas de la red no tienen usuario.
    return find_by(email: login.downcase) if login.include?("@")
    por_celular = find_by(celular: normalizar_celular(login)) if login.match?(/\A[\d\s+().-]+\z/)
    por_celular || find_by("LOWER(username) = ?", login.downcase)
  end

  # «+57 350 691 0000», «350-691-0000» y «3506910000» son el mismo celular.
  def self.normalizar_celular(texto)
    digitos = texto.to_s.gsub(/\D/, "")
    digitos = digitos.delete_prefix("57") if digitos.length == 12
    digitos.presence
  end

  # Contraseña temporal para dictarla o mandarla por WhatsApp: sin letras ni cifras que se confundan (l, 1, o, 0).
  ALFABETO_CLAVE_TEMPORAL = [*"a".."z", *"2".."9"].without("l", "o").freeze
  def self.clave_temporal = Array.new(10) { ALFABETO_CLAVE_TEMPORAL[SecureRandom.random_number(ALFABETO_CLAVE_TEMPORAL.size)] }.join

  scope :admins, -> { where(rol: [:admin_logia, :super_admin]) }
  scope :por_logia, ->(logia_id) { where(logia_id: logia_id) }
  # Quienes administran esas logias, sea o no la comunidad que tienen activa.
  scope :admins_de, ->(logia_ids) {
    where(id: Pertenencia.where(logia_id: logia_ids).joins(:rol_ref).where(roles: { codigo: "admin_logia" }).select(:user_id))
  }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  # ── Varias comunidades ───────────────────────────────────────
  # La ficha de la comunidad que se está mirando (Current.organizacion, la pone ApplicationController) o, fuera
  # de una petición, la de la comunidad activa de la cuenta. Así, en Uniandes se ve la ficha de Uniandes de
  # cualquiera, aunque esa persona tenga activa otra comunidad.
  def miembro
    organizacion = Current.organizacion || logia&.organizacion
    @fichas ||= {}
    @fichas[organizacion&.id] ||= if organizacion.nil?
      miembros.first
    else
      ids = organizacion.ids_de_la_organizacion
      miembros.loaded? ? miembros.detect { ids.include?(_1.logia_id) } : miembros.find_by(logia_id: ids)
    end
  end

  def reload(*)
    @fichas = nil
    super
  end

  # Comunidades (organizaciones raíz) de la cuenta, para el selector del menú.
  def comunidades
    Logia.where(id: pertenencias.select(:organizacion_id)).reales.ordenadas
  end

  # Si también pertenece a alguna comunidad distinta de esta.
  def de_otras_comunidades?(organizacion)
    pertenencias.where.not(organizacion_id: organizacion.id).exists?
  end

  def pertenece_a?(organizacion)
    logia&.organizacion == organizacion || pertenencias.exists?(organizacion_id: organizacion.id)
  end

  # Pasa a la comunidad indicada: su logia y su rol allí son desde ahora los de la cuenta, que es lo que leen
  # los permisos. El superadmin conserva su rol en todas. false si no pertenece a ella.
  def activar_comunidad!(organizacion)
    pertenencia = pertenencias.find_by(organizacion_id: organizacion.id) or return false
    rol = rol_ref&.es_super_admin? ? rol_ref : pertenencia.rol_ref
    return true if logia_id == pertenencia.logia_id && rol_ref_id == rol&.id
    update_columns(logia_id: pertenencia.logia_id, rol_ref_id: rol&.id, rol: ROL_POR_CODIGO.fetch(rol&.codigo, "miembro"))
    @fichas = nil
    true
  end

  # Añade la cuenta a otra comunidad sin cambiar la activa (lo hace el superadmin al vincular una cuenta).
  def unir_a_comunidad!(logia, rol: Rol.find_by!(codigo: "miembro"))
    pertenencias.find_or_create_by!(organizacion_id: logia.organizacion.id) { _1.assign_attributes(logia: logia, rol_ref: rol) }
  end

  # El rol en una comunidad: si es la activa, también el de la cuenta.
  def asignar_rol!(rol, en:)
    if logia&.organizacion == en.organizacion
      update!(rol_ref: rol)
    else
      pertenencias.find_by!(organizacion_id: en.organizacion.id).update!(rol_ref: rol)
    end
  end

  # Deja una comunidad (sus fichas y su pertenencia) y, si era la activa, pasa a otra de las suyas.
  def salir_de_comunidad!(organizacion)
    transaction do
      miembros.where(logia_id: organizacion.ids_de_la_organizacion).destroy_all
      pertenencias.where(organizacion_id: organizacion.id).destroy_all
      otra = pertenencias.reload.first
      activar_comunidad!(otra.organizacion) if otra && logia&.organizacion == organizacion
    end
  end

  def touch_last_seen!
    return if invitado? # la cuenta compartida de la demostración solo mira

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

  # Todos menos el superadmin quedan dentro de su logia; también sin rol o sin logia (un rol vacío no abre todo).
  def scope_propia_logia?
    !rol_ref&.es_super_admin?
  end

  # Returns the array of logia IDs this user can access.
  # - super_admin: nil (unrestricted)
  # - admin of root tenant: tenant_id + all child logia ids
  # - admin of sub-logia: just their logia_id
  def logia_ids_accesibles
    return nil unless scope_propia_logia?
    logia = self.logia
    return [] unless logia
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

  # La pertenencia de la comunidad activa sigue a la cuenta: crearla, cambiarle el rol o moverla de logia (el
  # superadmin) se guarda también ahí. Si la logia nueva es de otra comunidad, la cuenta se mudó y deja la
  # anterior.
  def guardar_pertenencia
    return unless logia
    if saved_change_to_logia_id? && (anterior = Logia.find_by(id: logia_id_before_last_save)) &&
       anterior.organizacion != logia.organizacion
      pertenencias.where(organizacion_id: anterior.organizacion.id).destroy_all
    end
    pertenencias.find_or_initialize_by(organizacion_id: logia.organizacion.id).update!(logia: logia, rol_ref: rol_ref)
  end

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
    # Sin apellido (entró con el celular y aún no lo da) se usa el nombre entero: «juancamilo», no «j».
    (a.present? ? "#{n[0]}#{a}" : n).downcase.gsub(/[^a-z0-9]/, "").presence || "user"
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
