module Github
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    def receive
      payload_body = request.raw_post
      signature = request.headers["X-Hub-Signature-256"]

      verification = Github::WebhookVerificationService.call(payload_body: payload_body, signature_header: signature)
      unless verification.success?
        Rails.logger.warn("GitHub webhook verification failed: #{verification.error}")
        head :unauthorized
        return
      end

      event = request.headers["X-GitHub-Event"]
      payload = JSON.parse(payload_body)

      dispatch = Github::WebhookDispatchService.call(event: event, payload: payload)
      if dispatch.failure?
        Rails.logger.error("GitHub webhook dispatch failed: #{dispatch.error}")
        head :internal_server_error
      else
        head :ok
      end
    rescue JSON::ParserError => e
      Rails.logger.error("GitHub webhook payload malformed: #{e.message}")
      head :bad_request
    end
  end
end
