module Denuncias
  class Reporte < ApplicationRecord
    ESTADOS = %w[publicado oculto retirado].freeze

    has_many :evidencias, -> { order(:orden) }, foreign_key: :reporte_id
    has_many :eventos, -> { order(:n) }, class_name: "EventoCustodia", foreign_key: :reporte_id
    has_many :solicitudes_retiro, foreign_key: :reporte_id, class_name: "SolicitudRetiro"
    has_many :remisiones, foreign_key: :reporte_id
    # Quien la publicó. En el muro no se muestra: lo ven el operador y el propio autor.
    belongs_to :user, optional: true

    scope :publicados, -> { where(estado: "publicado") }

    def self.por_id(id) = find_by(id: id.to_s)

    # Nombres de las copias públicas (sin EXIF) de sus fotos.
    def fotos_publicas = evidencias.filter_map { File.basename(_1.clave_publica) if _1.clave_publica }

    # En público solo se da el día, no la hora.
    def fecha = Date.iso8601(Cripto.fecha_bogota(creado_en))
  end
end
