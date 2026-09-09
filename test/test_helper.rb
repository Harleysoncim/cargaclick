ENV["RAILS_ENV"] ||= "test"
abort "Rails tests require RAILS_ENV=test" unless ENV["RAILS_ENV"] == "test"
require_relative "../config/environment"
require "rails/test_help"

# 🔥 Carrega automaticamente drivers, helpers e configs de system test
Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    # fixtures :all
  end
end

