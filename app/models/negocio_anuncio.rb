class NegocioAnuncio < ApplicationRecord
  include AttachmentValidations

  TIPOS = %w[servicio producto empleo].freeze
  TIPO_LABEL = {
    "servicio" => "Servicio",
    "producto" => "Producto",
    "empleo"   => "Empleo"
  }.freeze
  TIPO_COLOR = {
    "servicio" => "primary",
    "producto" => "success",
    "empleo"   => "warning"
  }.freeze

  ESTADOS = %w[disponible reservado vendido pausado].freeze
  ESTADO_LABEL = {
    "disponible" => "Disponible",
    "reservado"  => "Reservado",
    "vendido"    => "Vendido",
    "pausado"    => "Pausado"
  }.freeze

  CATEGORIAS_SERVICIO = %w[Consultoría Legal Salud Construcción Tecnología Educación Transporte Finanzas Otro].freeze
  CATEGORIAS_PRODUCTO = %w[Hogar Electrónica Moda Vehículos Libros Deportes Alimentación Arte Otro].freeze
  CATEGORIAS_EMPLEO   = ["Tiempo completo", "Medio tiempo", "Freelance", "Prácticas", "Otro"].freeze

  belongs_to :logia
  belongs_to :user
  has_one_attached :imagen
  has_many_attached :imagenes
  validates_attachment :imagen,   types: :image, max: 8.megabytes
  validates_attachment :imagenes, types: :image, max: 8.megabytes, multi: true
  has_many :favoritos, class_name: "NegocioFavorito", dependent: :destroy
  has_many :usuarios_favoritos, through: :favoritos, source: :user
  has_many :conversaciones, class_name: "NegocioConversacion", dependent: :destroy
  has_many :reportes,       class_name: "NegocioReporte",      dependent: :destroy

  validates :titulo, presence: true, length: { maximum: 200 }
  validates :tipo,   presence: true, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }, allow_nil: true
  validate  :validate_imagenes

  before_validation :generar_slug
  before_save       :generar_slug

  def to_param
    slug.presence || id.to_s
  end

  def self.find_by_slug_or_id(param)
    find_by(slug: param) || find(param)
  end

  scope :activos,   -> { where(activo: true) }
  scope :de_logia,  ->(id) { where(logia_id: id) }
  scope :de_tipo,   ->(t) { where(tipo: t) }
  scope :ordenados, -> { order(created_at: :desc) }
  scope :buscar,    ->(q) {
    where("titulo ILIKE :q OR descripcion ILIKE :q OR categoria ILIKE :q", q: "%#{q}%")
  }
  scope :disponibles, -> { where(estado: "disponible") }

  def tipo_label
    TIPO_LABEL[tipo] || tipo.humanize
  end

  def tipo_color
    TIPO_COLOR[tipo] || "secondary"
  end

  def estado_label
    ESTADO_LABEL[estado] || estado&.humanize || "Disponible"
  end

  def categorias_sugeridas
    case tipo
    when "servicio" then CATEGORIAS_SERVICIO
    when "producto" then CATEGORIAS_PRODUCTO
    when "empleo"   then CATEGORIAS_EMPLEO
    else []
    end
  end

  def favorito_de?(user)
    return false if user.blank?
    favoritos.exists?(user_id: user.id)
  end

  def imagenes_o_legacy
    return imagenes.to_a if imagenes.attached?
    imagen.attached? ? [imagen] : []
  end

  def imagen_principal
    imagenes_o_legacy.first
  end

  private

  def generar_slug
    return if titulo.blank?
    return if slug.present? && !titulo_changed?
    base = titulo.to_s.downcase
              .tr("áéíóúñ", "aeioun")
              .gsub(/[^a-z0-9\s-]/, "")
              .strip
              .gsub(/\s+/, "-")[0, 80]
    candidate = base
    n = 1
    while NegocioAnuncio.where.not(id: id).exists?(slug: candidate)
      n += 1
      candidate = "#{base}-#{n}"
    end
    self.slug = candidate
  end

  def validate_imagenes
    return unless imagenes.attached?
    if imagenes.count > 10
      errors.add(:imagenes, "máximo 10 imágenes por anuncio")
    end
    imagenes.each do |img|
      if img.blob.byte_size > 8.megabytes
        errors.add(:imagenes, "cada imagen no debe superar 8 MB")
        break
      end
      unless img.blob.content_type.to_s.start_with?("image/")
        errors.add(:imagenes, "solo se aceptan archivos de imagen")
        break
      end
    end
  end
end
