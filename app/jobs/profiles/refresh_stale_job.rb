module Profiles
  class RefreshStaleJob < ApplicationJob
    queue_as :default

    # Refresh a batch of stale profiles (avatar + data) to keep things fresh.
    # Stale if last_synced_at older than `stale_after` (default 6h).
    def perform(limit: 200, stale_after: 6.hours)
      started = Time.current
      cutoff = Time.current - stale_after

      stale = Profile.where("last_synced_at IS NULL OR last_synced_at < ?", cutoff)
                     .order(:last_synced_at)
                     .limit(limit.to_i)

      count = 0
      stale.pluck(:login).each do |login|
        Profiles::RefreshJob.perform_later(login)
        count += 1
      end

      StructuredLogger.info(message: "refresh_stale_enqueued", count: count, duration_ms: ((Time.current - started) * 1000).to_i)
    end
  end
end
