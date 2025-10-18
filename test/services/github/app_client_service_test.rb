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

    test "returns unauthenticated client when installation token fails (fallback)" do
      Github::InstallationTokenService.stub :call, ServiceResult.failure(StandardError.new("nope")) do
        # Expect a fallback Octokit::Client without an access token
        Octokit::Client.stub :new, ->(**_opts) { :unauth_client } do
          result = Github::AppClientService.call

          assert result.success?
          assert_equal :unauth_client, result.value
          assert_equal "unauthenticated", result.metadata[:fallback]
        end
      end
    end
  end
end
