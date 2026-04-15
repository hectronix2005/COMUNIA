class CalendarioSincronizacion < ApplicationRecord
  self.table_name = "calendario_sincronizaciones"

  ESTADOS = %w[pendiente aceptada rechazada].freeze

  belongs_to :logia_solicitante, class_name: "Logia"
  belongs_to :logia_destino,     class_name: "Logia"
  belongs_to :solicitado_por,    class_name: "User"

  validates :estado, inclusion: { in: ESTADOS }
  validates :logia_solicitante_id, uniqueness: {
    scope: :logia_destino_id,
    message: "ya existe una solicitud entre estas logias"
  }
  validate :logias_distintas

  scope :pendientes, -> { where(estado: "pendiente") }
  scope :aceptadas,  -> { where(estado: "aceptada") }
  scope :para_logia, ->(logia_id) {
    where(logia_solicitante_id: logia_id).or(where(logia_destino_id: logia_id))
  }
  scope :aceptadas_para_logia, ->(logia_id) { aceptadas.para_logia(logia_id) }

  def pendiente? = estado == "pendiente"
  def aceptada?  = estado == "aceptada"
  def rechazada? = estado == "rechazada"

  private

  def logias_distintas
    return unless logia_solicitante_id.present? && logia_destino_id.present?
    errors.add(:base, "No puedes sincronizar con tu propia logia") if logia_solicitante_id == logia_destino_id
  end
end
