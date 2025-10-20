module Github
  class WebhooksController < ApplicationController
    # Webhooks are authenticated by HMAC signature and must bypass CSRF.
    # CSRF protection remains enabled for the rest of the app.
    skip_forgery_protection only: :receive

    # Lightweight trigger to hot rebuild leaderboards when stars/watchers change
    def receive
      return head :method_not_allowed unless request.post?
      return head :unsupported_media_type unless request.media_type == "application/json"

      sig = request.headers["X-Hub-Signature-256"].to_s
      verification = Github::WebhookVerificationService.call(payload_body: request.raw_post, signature_header: sig)
      return head :unauthorized unless verification.success?

      event = request.headers["X-GitHub-Event"].to_s
      case event
      when "watch", "star", "push", "release"
        Leaderboards::RebuildJob.perform_later
      end
      head :ok
    end
  end
end
