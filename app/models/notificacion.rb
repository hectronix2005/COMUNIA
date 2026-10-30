class Notificacion < ApplicationRecord
  belongs_to :user
  belongs_to :logia, optional: true

  validates :tipo,   presence: true
  validates :titulo, presence: true

  scope :no_leidas, -> { where(leida: false) }
  scope :recientes, -> { order(created_at: :desc).limit(30) }

  # Cada aviso es de la comunidad de su logia; sin logia son los personales (la red, los errores de la plataforma).
  # Dentro de una comunidad solo se ven los suyos y los personales: nunca los de otra, aunque sean de la misma persona.
  scope :personales, -> { where(logia_id: nil) }
  scope :de_la_comunidad, ->(organizacion) { where(logia_id: organizacion.ids_de_la_organizacion) }
  scope :visibles_en, ->(organizacion) { organizacion ? de_la_comunidad(organizacion).or(personales) : personales }

  def organizacion = logia&.organizacion

  # El enlace abre la comunidad del aviso (/t/<slug>/...), aunque se toque desde otra o desde el teléfono: así se
  # activa la suya y no se busca lo de una comunidad dentro de otra.
  def enlace
    destino = url.presence || "/dashboard"
    slug = organizacion&.slug
    return destino if slug.blank? || !destino.start_with?("/") || destino.start_with?("//", "/t/")
    "/t/#{slug}#{destino}"
  end

  # Rótulo de los que no son de una comunidad.
  def origen
    if tipo.start_with?("red_") then "Red"
    elsif logia.nil? then "COMUNIA"
    end
  end

  def marcar_leida!
    update!(leida: true, leida_at: Time.current)
  end
end
