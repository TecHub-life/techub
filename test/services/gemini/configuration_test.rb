require "test_helper"

module Gemini
  class ConfigurationTest < ActiveSupport::TestCase
    CredentialsStub = Struct.new(:payload) do
      def dig(*keys)
        payload.dig(*keys)
      end
    end

    setup do
      ENV.delete("GEMINI_PROVIDER")
      ENV.delete("GOOGLE_CLOUD_PROJECT")
      ENV.delete("GEMINI_LOCATION")
      ENV.delete("GEMINI_API_KEY")
      ENV.delete("GEMINI_API_BASE")
      ENV.delete("GOOGLE_APPLICATION_CREDENTIALS")
    end

    test "defaults to vertex provider" do
      Rails.application.stub :credentials, CredentialsStub.new({}) do
        assert_equal "vertex", Gemini::Configuration.provider
      end
    end

    test "reads google top-level keys" do
      creds = {
        google: {
          project_id: "proj-123",
          location: "europe-west1",
          application_credentials_path: "/tmp/key.json"
        }
      }
      Rails.application.stub :credentials, CredentialsStub.new(creds) do
        assert_equal "proj-123", Gemini::Configuration.project_id
        assert_equal "europe-west1", Gemini::Configuration.location
        assert_equal "/tmp/key.json", Gemini::Configuration.application_credentials_path
      end
    end

    test "reads gemini nested keys" do
      creds = {
        gemini: {
          provider: "ai_studio",
          api_key: "xyz",
          api_base: "https://example"
        }
      }
      Rails.application.stub :credentials, CredentialsStub.new(creds) do
        assert_equal "ai_studio", Gemini::Configuration.provider
        assert_equal "xyz", Gemini::Configuration.api_key
        assert_equal "https://example", Gemini::Configuration.api_base
      end
    end

    test "env overrides credentials" do
      ENV["GEMINI_PROVIDER"] = "ai_studio"
      ENV["GEMINI_API_KEY"] = "env-key"
      ENV["GOOGLE_CLOUD_PROJECT"] = "env-proj"
      Rails.application.stub :credentials, CredentialsStub.new({ gemini: { api_key: "cred-key" } }) do
        assert_equal "ai_studio", Gemini::Configuration.provider
        assert_equal "env-key", Gemini::Configuration.api_key
        assert_equal "env-proj", Gemini::Configuration.project_id
      end
    end

    test "validate! requires project for vertex" do
      Rails.application.stub :credentials, CredentialsStub.new({}) do
        assert_raises(KeyError) { Gemini::Configuration.validate! }
      end

      Rails.application.stub :credentials, CredentialsStub.new({ google: { project_id: "p" } }) do
        assert_equal true, Gemini::Configuration.validate!
      end
    end

    test "validate! requires api key for ai studio" do
      ENV["GEMINI_PROVIDER"] = "ai_studio"
      Rails.application.stub :credentials, CredentialsStub.new({}) do
        assert_raises(KeyError) { Gemini::Configuration.validate! }
      end
      Rails.application.stub :credentials, CredentialsStub.new({ gemini: { api_key: "k" } }) do
        assert_equal true, Gemini::Configuration.validate!
      end
    end
  end
end
