require "test_helper"
require "webmock/minitest"

module Github
  class AppClientServiceTest < ActiveSupport::TestCase
    test "returns octokit client when installation token succeeds" do
      expires_at = Time.now.utc + 3600

      Github::AppAuthenticationService.stub :call, ServiceResult.success("jwt-token") do
        stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
          .to_return(status: 200, body: { token: "abc123", expires_at: expires_at.iso8601, permissions: { contents: "read" } }.to_json, headers: { "Content-Type" => "application/json" })

        result = Github::AppClientService.call(installation_id: 42)
        assert result.success?, -> { result.error&.message }
        assert_in_delta expires_at.to_i, result.metadata[:expires_at].to_i, 2
      end
    end

    test "bubbles up failure when token creation fails" do
      Github::AppAuthenticationService.stub :call, ServiceResult.success("jwt-token") do
        stub_request(:post, "https://api.github.com/app/installations/90542889/access_tokens")
          .to_return(status: 404, body: "{}", headers: { "Content-Type" => "application/json" })

        result = Github::AppClientService.call(installation_id: 90542889)
        assert result.failure?
      end
    end
  end
end
