require "test_helper"

module Github
  class AppAuthenticationServiceTest < ActiveSupport::TestCase
    setup do
      @private_key = OpenSSL::PKey::RSA.generate(2048)
      ENV["GITHUB_APP_ID"] = "12345"
      ENV["GITHUB_PRIVATE_KEY"] = @private_key.to_pem
      Github::Configuration.reset!
    end

    teardown do
      ENV.delete("GITHUB_APP_ID")
      ENV.delete("GITHUB_PRIVATE_KEY")
      Github::Configuration.reset!
    end

    test "returns a signed JWT" do
      result = Github::AppAuthenticationService.call

      assert result.success?, "expected service to succeed"

      token = result.value
      decoded, = JWT.decode(token, @private_key.public_key, true, { algorithm: "RS256" })
      assert_equal "12345", decoded["iss"]
    end
  end
end
