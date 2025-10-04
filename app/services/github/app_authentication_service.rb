require "jwt"
require "openssl"

module Github
  class AppAuthenticationService < ApplicationService
    TOKEN_TTL = 9.minutes

    def call
      now = Time.now.utc
      payload = {
        iat: now.to_i,
        exp: (now + TOKEN_TTL).to_i,
        iss: Github::Configuration.app_id
      }

      private_key = OpenSSL::PKey::RSA.new(Github::Configuration.private_key)
      token = JWT.encode(payload, private_key, "RS256")

      success(token, metadata: { expires_at: payload[:exp] })
    rescue KeyError, OpenSSL::PKey::PKeyError, JWT::EncodeError => e
      failure(e)
    end
  end
end
