# Comunidad sombrilla: un barrio, una localidad o una ciudad, sin admin. No se entra a ella: se está dentro por
# pertenecer a una comunidad de categoría Barrio anclada a un barrio (logias.sombrilla_id), y con el barrio vienen
# su localidad y su ciudad. Solo tiene muro, eventos y noticias; lo privado de cada comunidad nunca sube.
# El catálogo lo lleva el superadmin.
class Sombrilla < ApplicationRecord
  NIVELES = { "barrio" => "Barrio", "localidad" => "Localidad", "ciudad" => "Ciudad" }.freeze
  NIVEL_DEL_PADRE = { "barrio" => "localidad", "localidad" => "ciudad", "ciudad" => nil }.freeze
  ICONOS = { "barrio" => "houses", "localidad" => "signpost-2", "ciudad" => "buildings" }.freeze
  CATEGORIA_ANCLABLE = "Barrio".freeze

  belongs_to :padre, class_name: "Sombrilla", optional: true
  has_many :hijas, class_name: "Sombrilla", foreign_key: :padre_id, inverse_of: :padre, dependent: :restrict_with_error
  has_many :comunidades, class_name: "Logia", dependent: :restrict_with_error
  has_many :publicaciones, class_name: "SombrillaPublicacion", dependent: :destroy
  has_many :eventos, class_name: "SombrillaEvento", dependent: :destroy
  has_many :noticias, dependent: :delete_all

  validates :nombre, presence: true, length: { in: 2..60 }
  validates :nivel, inclusion: { in: NIVELES.keys }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validate do
    esperado = NIVEL_DEL_PADRE[nivel]
    if esperado.nil?
      errors.add(:padre, "no aplica a una ciudad") if padre
    elsif padre&.nivel != esperado
      errors.add(:padre, "debe ser una #{NIVELES[esperado].downcase}")
    end
  end

  before_validation do
    self.nombre = nombre.to_s.squish
    self.noticias_busquedas = [nombre_para_noticias] if noticias_busquedas.blank? && nombre.present?
    if slug.blank? && nombre.present?
      base = nombre.parameterize
      self.slug = Sombrilla.where(slug: base).where.not(id: id).exists? ? "#{base}-#{padre&.slug || nivel}" : base
    end
  end

  scope :ordenadas, -> { order(:nombre) }
  scope :barrios, -> { where(nivel: "barrio") }

  def to_param = slug
  def nivel_nombre = NIVELES[nivel]
  def icono = ICONOS[nivel]

  # Ella y las de arriba: Cedritos, Usaquén, Bogotá.
  def cadena = [self, *padre&.cadena]

  # Ella y las de abajo (como mucho dos niveles más).
  def ids_debajo
    ids = [id]
    nivel_actual = [id]
    2.times do
      nivel_actual = Sombrilla.where(padre_id: nivel_actual).ids
      ids.concat(nivel_actual)
    end
    ids
  end

  # Las comunidades ancladas debajo: las que la forman.
  def comunidades_debajo = Logia.where(sombrilla_id: ids_debajo)

  # Las sombrillas a las que llega una cuenta, de abajo arriba y sin repetir.
  def self.de_usuario(user)
    return none unless user

    barrios = comunidades_de(user).distinct.pluck(:sombrilla_id)
    ids = Sombrilla.where(id: barrios).flat_map { _1.cadena.map(&:id) }.uniq
    where(id: ids).in_order_of(:nivel, NIVELES.keys)
  end

  # Las comunidades de la cuenta que la ponen bajo alguna sombrilla.
  def self.comunidades_de(user)
    organizaciones = user.pertenencias.select(:organizacion_id)
    Logia.where(id: organizaciones).or(Logia.where(id: user.logia&.organizacion&.id))
         .where.not(sombrilla_id: nil).joins(:categoria).where(categorias: { nombre: CATEGORIA_ANCLABLE })
  end

  def accesible_para?(user)
    return false unless user
    return true if user.rol_ref&.es_super_admin?

    comunidad_de(user).present?
  end

  # La comunidad desde la que la cuenta participa aquí: la activa si está debajo; si no, la primera.
  def comunidad_de(user)
    debajo = Sombrilla.comunidades_de(user).where(sombrilla_id: ids_debajo)
    activa = user.logia&.organizacion
    activa && debajo.include?(activa) ? activa : debajo.order(:id).first
  end

  # Ve todo (nombres completos y lo oculto) y oculta: el superadmin y los admins de las comunidades de abajo.
  def modera?(user)
    return false unless user
    return true if user.rol_ref&.es_super_admin?

    user.pertenencias.joins(:rol_ref).where(roles: { codigo: "admin_logia" })
        .exists?(organizacion_id: comunidades_debajo.joins(:categoria).where(categorias: { nombre: CATEGORIA_ANCLABLE }).select(:id))
  end

  # Para Google Noticias: «Cedritos Bogotá», «localidad de Usaquén», «Bogotá».
  def nombre_para_noticias
    case nivel
    when "barrio" then [nombre, padre&.padre&.nombre].compact.join(" ")
    when "localidad" then "localidad de #{nombre}"
    else nombre
    end
  end
end
