module Profiles
  class RecordDailyStatsJob < ApplicationJob
    queue_as :default

    # Capture a daily snapshot of key profile metrics for trends/analytics.
    def perform(limit: nil, date: Date.today)
      scope = Profile.all
      scope = scope.limit(limit.to_i) if limit.present?

      scope.find_each do |p|
        begin
          totals = p.profile_repositories.pluck(:stargazers_count, :forks_count)
          stars = totals.sum { |row| row[0].to_i }
          forks = totals.sum { |row| row[1].to_i }

          stat = ProfileStat.find_or_initialize_by(profile_id: p.id, stat_date: date)
          stat.followers = p.followers.to_i
          stat.following = p.following.to_i
          stat.public_repos = p.public_repos.to_i
          stat.total_stars = stars
          stat.total_forks = forks
          stat.repo_count = p.profile_repositories.count
          stat.captured_at = Time.current
          stat.save!

          event = { message: "profile_daily_stats", login: p.login, date: date, followers: stat.followers, following: stat.following, public_repos: stat.public_repos, total_stars: stars, total_forks: forks, repo_count: stat.repo_count }
          StructuredLogger.info(event) if defined?(StructuredLogger)

          # Optional: send to a dedicated Axiom dataset for metrics
          metrics_dataset = (
            (Rails.application.credentials.dig(:axiom, :metrics_dataset) rescue nil) ||
            ENV["AXIOM_METRICS_DATASET"] ||
            (Rails.application.credentials.dig(:axiom, :dataset) rescue nil) ||
            ENV["AXIOM_DATASET"]
          )
          if metrics_dataset.present?
            begin
              Axiom::IngestService.call(dataset: metrics_dataset, events: [ event.merge(ts: Time.current.utc.iso8601, level: "INFO", kind: "profile_stats") ])
            rescue StandardError => e
              StructuredLogger.warn(message: "axiom_metrics_ingest_failed", login: p.login, error: e.message) if defined?(StructuredLogger)
            end
          end
        rescue StandardError => e
          StructuredLogger.warn(message: "profile_daily_stats_failed", login: p.login, error: e.message) if defined?(StructuredLogger)
        end
      end
    end
  end
end
