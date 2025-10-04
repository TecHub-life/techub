require "test_helper"

module Github
  class WebhookVerificationServiceTest < ActiveSupport::TestCase
    setup do
      ENV["GITHUB_WEBHOOK_SECRET"] = "secret"
      Github::Configuration.reset!
    end

    teardown do
      ENV.delete("GITHUB_WEBHOOK_SECRET")
      Github::Configuration.reset!
    end

    test "validates signature" do
      body = { action: "test" }.to_json
      signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "secret", body)

      result = Github::WebhookVerificationService.call(payload_body: body, signature_header: signature)

      assert result.success?
    end

    test "fails on mismatch" do
      body = { action: "test" }.to_json
      result = Github::WebhookVerificationService.call(payload_body: body, signature_header: "sha256=bad")

      assert result.failure?
    end
  end
end
