require "webmock/minitest"
require "securerandom"

ENV["RAILS_ENV"] ||= "test"
# Disable OpenTelemetry in tests to prevent hanging on external requests
ENV["OTEL_DISABLED"] = "true"
ENV["OTEL_SDK_DISABLED"] = "true"
ENV["OTEL_TRACES_EXPORTER"] = "none"
ENV["OTEL_METRICS_EXPORTER"] = "none"
ENV["OTEL_LOGS_EXPORTER"] = "none"

WebMock.disable_net_connect!(allow_localhost: true)

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |path| require path }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors, threshold: 10) unless ENV["DISABLE_PARALLEL_TESTS"] == "1"
    fixtures :all
    self.use_transactional_tests = true

    private

    def unique_login(prefix = "user")
      "#{prefix}-#{SecureRandom.hex(4)}"
    end

    def unique_github_id
      SecureRandom.random_number(1_000_000_000) + 1_000_000
    end
  end
end

ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] ||= "techub:hunter2"
