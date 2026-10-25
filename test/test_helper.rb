ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/denuncias_prueba"
require_relative "support/red_prueba"

# schema.rb no guarda triggers: la cadena de custodia de DENUNCIAPP los necesita.
Denuncias::Esquema.triggers!

class ActiveSupport::TestCase
  # No fixtures — use programmatic setup to avoid FK complexity
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
