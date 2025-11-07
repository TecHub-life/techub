require "webmock/minitest"
require "securerandom"

ENV["RAILS_ENV"] ||= "test"
# Disable OpenTelemetry in tests to prevent hanging on external requests
ENV["OTEL_SDK_DISABLED"] = "true"
ENV["OTEL_TRACES_EXPORTER"] = "none"
ENV["OTEL_METRICS_EXPORTER"] = "none"
ENV["OTEL_LOGS_EXPORTER"] = "none"

# Stub OpenTelemetry before it loads
WebMock.disable_net_connect!(allow_localhost: true)
WebMock.stub_request(:post, /api\.honeycomb\.io/).to_return(status: 200, body: "", headers: {})

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

    private

    def unique_login(prefix = "user")
      "#{prefix}-#{SecureRandom.hex(4)}"
    end

    def unique_github_id
      SecureRandom.random_number(1_000_000_000) + 1_000_000
    end
  end
end

# Provide default HTTP Basic for Ops in test environment
ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] ||= "techub:hunter2"
