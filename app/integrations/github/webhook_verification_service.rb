require "openssl"

module Github
  class WebhookVerificationService < ApplicationService
    def initialize(payload_body:, signature_header:)
      @payload_body = payload_body
      @signature_header = signature_header.to_s
    end

    def call
      secret = Github::Configuration.webhook_secret
      if secret.blank?
        return failure(StandardError.new("GITHUB_WEBHOOK_SECRET is not configured"))
      end

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload_body)

      if secure_compare(expected, signature_header)
        success
      else
        failure(StandardError.new("Signature mismatch"))
      end
    end

    private

    attr_reader :payload_body, :signature_header

    def secure_compare(expected, given)
      return false if expected.blank? || given.blank?

      ActiveSupport::SecurityUtils.secure_compare(expected, given)
    rescue ArgumentError
      false
    end
  end
end
