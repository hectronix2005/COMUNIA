# Una visita del rastreo de pruebas (config/initializers/ahoy.rb): de que alguien llega hasta que pasa
# media hora sin hacer nada.
class Ahoy::Visit < ApplicationRecord
  self.table_name = "ahoy_visits"

  has_many :events, class_name: "Ahoy::Event", dependent: :delete_all
  belongs_to :user, optional: true
end
