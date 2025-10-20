module Github
  class WebhooksController < ApplicationController
    # Lightweight trigger to hot rebuild leaderboards when stars/watchers change
    def receive
      return head :method_not_allowed unless request.post?
      return head :unsupported_media_type unless request.media_type == "application/json"

      event = request.headers["X-GitHub-Event"].to_s
      case event
      when "watch", "star", "push", "release"
        Leaderboards::RebuildJob.perform_later
      end
      head :ok
    end

    private

    # Accept either Rails' CSRF token OR a valid GitHub HMAC signature.
    def verified_request?
      super || valid_github_signature?
    end

    def valid_github_signature?
      sig = request.headers["X-Hub-Signature-256"].to_s
      Github::WebhookVerificationService.call(payload_body: request.raw_post, signature_header: sig).success?
    end
  end
end
