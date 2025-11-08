require "test_helper"

module Gemini
  class ClientServiceTest < ActiveSupport::TestCase
    CredentialsStub = Struct.new(:payload) do
      def dig(*keys)
        payload.dig(*keys)
      end
    end

    test "builds Faraday client with bearer token" do
      creds = { google: { project_id: "proj", location: "us-central1", application_credentials_json: { "type" => "service_account" }.to_json } }
      Rails.application.stub :credentials, CredentialsStub.new(creds) do
        fake_auth = Minitest::Mock.new
        def fake_auth.fetch_access_token!; { "access_token"=>"t" }; end
        def fake_auth.access_token; "t"; end

        Google::Auth::ServiceAccountCredentials.stub :make_creds, fake_auth do
          Gemini::Configuration.stub :provider, "vertex" do
            result = Gemini::ClientService.call
            assert result.success?
            conn = result.value
            assert_equal "Bearer t", conn.headers["Authorization"]
          end
        end
      end
    end

    test "builds Faraday client with api key for ai studio" do
      ENV["GEMINI_PROVIDER"] = "ai_studio"
      ENV["GEMINI_API_KEY"] = "api-key-123"

      result = Gemini::ClientService.call
      assert result.success?
      conn = result.value
      assert_equal "https://generativelanguage.googleapis.com/v1beta", conn.url_prefix.to_s
      assert_equal "api-key-123", conn.headers["x-goog-api-key"]
      assert_nil conn.headers["Authorization"], "AI Studio client should not set bearer token"
    ensure
      ENV.delete("GEMINI_PROVIDER")
      ENV.delete("GEMINI_API_KEY")
    end

    test "allows overriding provider to ai studio even when configuration defaults to vertex" do
      ENV.delete("GEMINI_PROVIDER")
      ENV["GEMINI_API_KEY"] = "override-key"

      Gemini::Configuration.stub :provider, "vertex" do
        result = Gemini::ClientService.call(provider: "ai_studio")
        assert result.success?
        conn = result.value
        assert_equal "https://generativelanguage.googleapis.com/v1beta", conn.url_prefix.to_s
        assert_equal "override-key", conn.headers["x-goog-api-key"]
        assert_nil conn.headers["Authorization"]
      end
    ensure
      ENV.delete("GEMINI_API_KEY")
    end
  end
end
