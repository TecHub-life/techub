require "test_helper"

module Github
  class AppClientServiceTest < ActiveSupport::TestCase
    test "returns octokit client when installation token succeeds" do
      expires_at = Time.current + 1.hour
      payload = { token: "abc123", expires_at: expires_at, permissions: { contents: "read" } }

      Github::InstallationTokenService.stub :call, ServiceResult.success(payload) do
        fake_client = Object.new

        Octokit::Client.stub :new, ->(access_token:) do
          assert_equal "abc123", access_token
          fake_client
        end do
          result = Github::AppClientService.call(installation_id: 42)

          assert result.success?
          assert_equal fake_client, result.value
          assert_equal expires_at, result.metadata[:expires_at]
        end
      end
    end

    test "bubbles up failure from installation token service" do
      error = StandardError.new("nope")

      Github::InstallationTokenService.stub :call, ServiceResult.failure(error) do
        result = Github::AppClientService.call

        assert result.failure?
        assert_equal error, result.error
      end
    end
  end
end
