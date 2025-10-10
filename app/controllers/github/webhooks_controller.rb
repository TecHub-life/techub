module Github
  class WebhooksController < ApplicationController
    # CSRF protection is intentionally disabled for webhook endpoints
    # This is safe because:
    # 1. GitHub webhooks are authenticated using HMAC signatures (X-Hub-Signature-256 header)
    # 2. The WebhookVerificationService validates signatures using secure comparison
    # 3. Webhooks don't use browser sessions or CSRF tokens
    # 4. All webhook requests must include valid HMAC signatures to be processed
    # @codeql-disable-next-line csrf-protection-disabled
    skip_before_action :verify_authenticity_token

    def receive
      payload_body = request.raw_post
      signature = request.headers["X-Hub-Signature-256"]

      verification = Github::WebhookVerificationService.call(payload_body: payload_body, signature_header: signature)
      unless verification.success?
        StructuredLogger.warn(message: "GitHub webhook verification failed", error: verification.error)
        head :unauthorized
        return
      end

      event = request.headers["X-GitHub-Event"]
      payload = JSON.parse(payload_body)

      dispatch = Github::WebhookDispatchService.call(event: event, payload: payload)
      if dispatch.failure?
        StructuredLogger.error(message: "GitHub webhook dispatch failed", error: dispatch.error)
        head :internal_server_error
      else
        head :ok
      end
    rescue JSON::ParserError => e
      StructuredLogger.error(message: "GitHub webhook payload malformed", error: e.message)
      head :bad_request
    end
  end
end
