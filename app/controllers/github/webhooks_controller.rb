module Github
  class WebhooksController < ApplicationController
    protect_from_forgery with: :null_session

    # Lightweight trigger to hot rebuild leaderboards when stars/watchers change
    def receive
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
