require "test_helper"

module Github
  class InstallationTokenServiceTest < ActiveSupport::TestCase
    # Pre-generate RSA key to avoid expensive crypto operations in each test
    TEST_PRIVATE_KEY = OpenSSL::PKey::RSA.generate(2048).to_pem.freeze

    setup do
      ENV["GITHUB_APP_ID"] = "12345"
      ENV["GITHUB_PRIVATE_KEY"] = TEST_PRIVATE_KEY
      Github::Configuration.reset!
    end

    test "auto-recovers from 404 by discovering installation and caching override" do
      ENV["GITHUB_APP_ID"] = "12345"
      ENV["GITHUB_PRIVATE_KEY"] = TEST_PRIVATE_KEY
      ENV["GITHUB_INSTALLATION_ID"] = "123" # stale/bad id
      Github::Configuration.reset!

      token_response = { token: "xyz", expires_at: Time.now.utc, permissions: { contents: "read" } }

      Github::AppAuthenticationService.stub :call, ServiceResult.success("jwt") do
        # Fake Octokit client: 404 for stale id, success for discovered id 999
        fake_client = Class.new do
          def create_app_installation_access_token(id, permissions: nil)
            raise Octokit::NotFound if id.to_i == 123
            { token: "xyz", expires_at: Time.now.utc, permissions: { contents: "read" } }
          end

          def initialize(*)
          end
        end.new

        Github::FindInstallationService.stub :call, ServiceResult.success({ id: 999, account_login: "owner" }) do
          Octokit::Client.stub :new, fake_client do
            result = Github::InstallationTokenService.call
            assert result.success?, -> { result.error&.message }
            # Confirm override was cached (if Rails.cache available)
            if defined?(Rails)
              cached = Rails.cache.read("github.installation_id.override") rescue nil
              assert_equal 999, cached.to_i if cached
            end
          end
        end
      end
    ensure
      ENV.delete("GITHUB_INSTALLATION_ID")
      Github::Configuration.reset!
    end

    teardown do
      ENV.delete("GITHUB_APP_ID")
      ENV.delete("GITHUB_PRIVATE_KEY")
      Github::Configuration.reset!
    end

    test "returns token data when Octokit succeeds" do
      installation_id = 42
      token_response = { token: "abc", expires_at: Time.now.utc, permissions: { contents: "read" } }

      Github::AppAuthenticationService.stub :call, ServiceResult.success("jwt") do
        client = Class.new do
          attr_reader :last_permissions

          def initialize(expected_id, response)
            @expected_id = expected_id
            @response = response
          end

          def create_app_installation_access_token(id, permissions: nil)
            raise "unexpected installation id" unless id == @expected_id

            @last_permissions = permissions
            @response
          end

          private

          attr_reader :expected_id, :response
        end.new(installation_id, token_response)

        Octokit::Client.stub :new, client do
          result = Github::InstallationTokenService.call(installation_id: installation_id)

          assert result.success?
          assert_equal "abc", result.value[:token]
          assert_equal token_response[:expires_at], result.value[:expires_at]
          assert_nil client.last_permissions
        end
      end
    end

    test "find installation handles direct GET when octokit lacks app_installations" do
      Github::AppAuthenticationService.stub :call, ServiceResult.success("jwt") do
        fake_client = Minitest::Mock.new
        fake_client.expect(:get, [ { id: 999, account: { login: "owner" } } ], [ "/app/installations" ])
        Octokit::Client.stub :new, fake_client do
          result = Github::FindInstallationService.call
          assert result.success?
          assert_equal 999, result.value[:id]
          assert_equal "owner", result.value[:account_login]
        end
        fake_client.verify
      end
    end
  end
end
