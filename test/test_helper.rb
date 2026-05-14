ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # No fixtures — use programmatic setup to avoid FK complexity
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
