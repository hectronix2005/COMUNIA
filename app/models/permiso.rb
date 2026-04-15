class Permiso < ApplicationRecord
  has_many :rol_permisos, dependent: :destroy
  has_many :roles, through: :rol_permisos

  validates :recurso, :accion, presence: true
  validates :accion, uniqueness: { scope: :recurso }

  scope :por_recurso, -> { order(:recurso, :accion) }

  RECURSOS_LABELS = {
    "logias" => "Logias",
    "miembros" => "Miembros",
    "periodos" => "Periodos de Cobro",
    "cobros" => "Cobros",
    "reportes" => "Reportes",
    "conceptos" => "Conceptos de Cobro",
    "roles" => "Roles y Permisos"
  }.freeze

  ACCIONES_LABELS = {
    "index" => "Ver listado",
    "show" => "Ver detalle",
    "create" => "Crear",
    "update" => "Editar",
    "destroy" => "Eliminar",
    "gestionar_conceptos" => "Gestionar conceptos",
    "adjuntar_soporte" => "Adjuntar soporte",
    "validar" => "Validar pago",
    "confirmar_pago" => "Confirmar pago",
    "rechazar_pago" => "Rechazar pago",
    "generar_cobros" => "Generar cobros",
    "cartera" => "Reporte cartera",
    "recaudacion" => "Reporte recaudacion",
    "morosos" => "Reporte morosos",
    "recibo" => "Recibo de caja",
    "gestionar_permisos" => "Gestionar permisos"
  }.freeze

  def recurso_label
    RECURSOS_LABELS[recurso] || recurso.humanize
  end

  def accion_label
    ACCIONES_LABELS[accion] || accion.humanize
  end

  def descripcion_completa
    "#{recurso_label}: #{accion_label}"
  end
end
