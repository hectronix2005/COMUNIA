class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :rol, { miembro: 0, admin_logia: 1, super_admin: 2 }

  belongs_to :logia, optional: true
  belongs_to :rol_ref, class_name: "Rol", optional: true
  has_one :miembro, dependent: :destroy
  has_many :negocio_favoritos, dependent: :destroy
  has_many :negocio_anuncios_favoritos, through: :negocio_favoritos, source: :negocio_anuncio

  validates :nombre, :apellido, presence: true
  validates :logia, presence: true, unless: :super_admin?
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9]+\z/, message: "solo letras minúsculas y números" },
                       if: -> { username.present? }

  before_validation :generate_username, on: :create, if: -> { username.blank? }

  def self.find_for_database_authentication(warden_conditions)
    login = warden_conditions[:email].to_s.strip
    return nil if login.blank?
    find_by("LOWER(username) = ?", login.downcase)
  end

  scope :admins, -> { where(rol: [:admin_logia, :super_admin]) }
  scope :por_logia, ->(logia_id) { where(logia_id: logia_id) }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  # Primer nombre + primer apellido ("Hector Andrey Neira Duque" → "Hector Neira")
  def nombre_corto
    primer_nombre   = nombre.to_s.strip.split(/\s+/).first
    primer_apellido = apellido.to_s.strip.split(/\s+/).first
    [primer_nombre, primer_apellido].compact.join(" ").presence || nombre_completo
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
