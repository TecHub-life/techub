require "test_helper"

module Github
  class ConfigurationTest < ActiveSupport::TestCase
    CredentialsStub = Struct.new(:payload) do
      def dig(*keys)
        payload.dig(*keys)
      end
    end

    setup do
      Github::Configuration.reset!
      clear_env!
    end

    teardown do
      Github::Configuration.reset!
      clear_env!
    end

    test "uses environment variables when available" do
      ENV["GITHUB_APP_ID"] = "env-app"
      credentials = CredentialsStub.new({ github: { app_id: "cred-app" } })

      Rails.application.stub :credentials, credentials do
        assert_equal "env-app", Github::Configuration.app_id
      end
    end

    test "falls back to credentials when env missing" do
      credentials = CredentialsStub.new({ github: { client_id: "cred-client" } })

      Rails.application.stub :credentials, credentials do
        assert_equal "cred-client", Github::Configuration.client_id
      end
    end

    test "reads private key from credential path" do
      pem = <<~PEM
        -----BEGIN PRIVATE KEY-----
        sample
        -----END PRIVATE KEY-----
      PEM
      path = Rails.root.join("tmp", "test-gh-app.pem")
      File.write(path, pem)

      credentials = CredentialsStub.new({ github: { private_key_path: path.to_s } })

      Rails.application.stub :credentials, credentials do
        assert_equal pem, Github::Configuration.private_key
      end
    ensure
      File.delete(path) if File.exist?(path)
    end

    test "raises when required config missing" do
      credentials = CredentialsStub.new({ github: {} })

      Rails.application.stub :credentials, credentials do
        assert_raises(KeyError) { Github::Configuration.client_secret }
      end
    end

    test "callback url uses environment variable in development" do
      ENV["GITHUB_CALLBACK_URL_DEV"] = "http://dev.test/auth/github/callback"
      Rails.application.stub :credentials, CredentialsStub.new({ github: { callback_url: "https://from-creds" } }) do
        assert_equal "http://dev.test/auth/github/callback", Github::Configuration.callback_url(default: "default")
      end
    end

    test "callback url falls back to credentials or default" do
      credentials = CredentialsStub.new({ github: { callback_url: "https://from-creds" } })

      Rails.application.stub :credentials, credentials do
        assert_equal "https://from-creds", Github::Configuration.callback_url(default: "default")
      end

      Rails.application.stub :credentials, CredentialsStub.new({ github: {} }) do
        assert_equal "default", Github::Configuration.callback_url(default: "default")
      end
    end

    private

    def clear_env!
      %w[
        GITHUB_APP_ID
        GITHUB_CLIENT_ID
        GITHUB_CLIENT_SECRET
        GITHUB_PRIVATE_KEY
        GITHUB_PRIVATE_KEY_PATH
        GITHUB_INSTALLATION_ID
        GITHUB_WEBHOOK_SECRET
        GITHUB_CALLBACK_URL_DEV
        GITHUB_CALLBACK_URL_PROD
      ].each { |key| ENV.delete(key) }
    end
  end
end
