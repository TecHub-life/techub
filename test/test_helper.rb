require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel unless explicitly disabled (helps in sandboxed envs)
    unless ENV["DISABLE_PARALLEL_TESTS"] == "1"
      parallelize(workers: :number_of_processors, threshold: 10)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Use transactional fixtures for faster database operations
    self.use_transactional_tests = true

    # Disable all external HTTP requests in tests by default
    WebMock.disable_net_connect!(allow_localhost: true)

    # Add more helper methods to be used by all tests here...
  end
end
