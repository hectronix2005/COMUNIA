# Tipo de comunidad (Masonería, Club, Barrio, Universidad…). La define el superadmin: cómo se llaman las
# personas, los grupos, las cuotas, las reuniones, el fondo de ayuda y los documentos, y qué módulos se ven.
class Categoria < ApplicationRecord
  MODULOS = {
    "tesoreria"  => "Tesorería y cuotas",
    "documentos" => "Documentos",
    "biblioteca" => "Biblioteca de libros",
    "ayuda"      => "Fondo de ayuda (recaudos y gastos)",
    "negocios"   => "Negocios",
    "reuniones"  => "Reuniones (convocatoria, asistencia y acta)",
    "grados"     => "Grados de los miembros"
  }.freeze

  TERMINOS = %w[miembro logia cobro reunion ayuda documentos].freeze
  ETIQUETAS_TERMINOS = {
    "miembro" => "Cada persona", "logia" => "Cada grupo", "cobro" => "Los cobros",
    "reunion" => "Las reuniones", "ayuda" => "El fondo de ayuda", "documentos" => "Los documentos"
  }.freeze

  has_many :logias, dependent: :restrict_with_error

  validates :nombre, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :icono, length: { maximum: 40 }, format: { with: /\A[a-z0-9-]*\z/ }
  TERMINOS.each { validates :"termino_#{_1}", length: { maximum: 40 } }

  before_validation { self.modulos = Array(modulos).compact_blank & MODULOS.keys }

  scope :ordenadas, -> { order(:nombre) }

  def modulo?(clave) = modulos.include?(clave.to_s)
end
