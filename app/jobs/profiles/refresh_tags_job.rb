module Profiles
  class RefreshTagsJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    # Recompute and normalize profile card tags for a batch of profiles.
    # Defaults: touch oldest updated cards first to gradually refresh the set.
    def perform(limit: 150)
      started = Time.current
      refreshed = 0

      scope = Profile.joins(:profile_card)
        .where(last_pipeline_status: "success")
        .order("profile_cards.updated_at ASC")
        .limit(limit.to_i)

      scope.find_each do |profile|
        begin
          result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
          refreshed += 1 if result.success?
        rescue StandardError => e
          StructuredLogger.warn(message: "tags_refresh_failed", login: profile.login, error: e.message)
        end
      end

      StructuredLogger.info(
        message: "tags_refresh_completed",
        batch_size: limit,
        refreshed: refreshed,
        duration_ms: ((Time.current - started) * 1000).to_i
      )
    end
  end
end
