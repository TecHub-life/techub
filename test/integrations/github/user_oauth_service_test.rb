require "test_helper"

module Github
  class UserOauthServiceTest < ActiveSupport::TestCase
    setup do
      ENV["GITHUB_CLIENT_ID"] = "client-id"
      ENV["GITHUB_CLIENT_SECRET"] = "client-secret"
    end

    teardown do
      ENV.delete("GITHUB_CLIENT_ID")
      ENV.delete("GITHUB_CLIENT_SECRET")
    end

    test "exchanges authorization code for access token" do
      stubbed_response = {
        access_token: "access-token",
        token_type: "bearer",
        scope: "read:user"
      }

      Octokit.stub :exchange_code_for_token, ->(code, client_id, client_secret, options = {}) do
        assert_equal "oauth-code", code
        assert_equal "client-id", client_id
        assert_equal "client-secret", client_secret
        assert_equal "http://example.com/callback", options[:redirect_uri]

        stubbed_response
      end do
        result = Github::UserOauthService.call(code: "oauth-code", redirect_uri: "http://example.com/callback")

        assert result.success?
        assert_equal stubbed_response[:access_token], result.value[:access_token]
        assert_equal stubbed_response[:token_type], result.value[:token_type]
        assert_equal stubbed_response[:scope], result.value[:scope]
      end
    end
  end
end
