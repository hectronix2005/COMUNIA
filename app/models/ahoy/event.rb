# Lo que pasó en una visita: cada petición al servidor («Petición»), cada vista con su tiempo en pantalla,
# clics, envíos de formularios y errores del navegador (app/javascript/rastreo.js).
class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, optional: true

  ERRORES = ["Error del navegador"].freeze
  scope :errores, -> { where(name: ERRORES).or(where("(properties->>'estado')::int >= 500")) }
end
