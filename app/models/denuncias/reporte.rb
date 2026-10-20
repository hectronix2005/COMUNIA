module Denuncias
  class Reporte < ApplicationRecord
    ESTADOS = %w[publicado oculto retirado].freeze

    has_many :evidencias, -> { order(:orden) }, foreign_key: :reporte_id
    has_many :eventos, -> { order(:n) }, class_name: "EventoCustodia", foreign_key: :reporte_id
    has_many :solicitudes_retiro, foreign_key: :reporte_id, class_name: "SolicitudRetiro"
    has_many :remisiones, foreign_key: :reporte_id
    belongs_to :cuenta, optional: true

    scope :publicados, -> { where(estado: "publicado") }

    def self.por_id(id) = find_by(id: id.to_s)

    # Lo que ve el público: la fecha (sin hora) y el sello solo si ya era público al recibirla.
    def a_publico
      { n: n, id: id, categoria: categoria, estado: estado, titulo: titulo, descripcion: descripcion,
        localidad: localidad, lugar: lugar, alias: cuenta&.alias, fecha: Cripto.fecha_bogota(creado_en),
        verificada: verificada && sello_publico,
        fotos: evidencias.filter_map { "/media/#{_1.clave_publica}" if _1.clave_publica } }
    end
  end
end
