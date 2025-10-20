module Leaderboards
  class ComputeService < ApplicationService
    def initialize(kind:, window: "30d", as_of: Date.today)
      @kind = kind.to_s
      @window = window.to_s
      @as_of = as_of
    end

    def call
      return failure(StandardError.new("invalid kind")) unless Leaderboard::KINDS.include?(kind)
      return failure(StandardError.new("invalid window")) unless Leaderboard::WINDOWS.include?(window)

      entries = case kind
      when "followers_total"
        followers_total
      when "followers_gain_7d", "followers_gain_30d"
        followers_gain
      when "stars_total"
        stars_total
      when "stars_gain_7d", "stars_gain_30d"
        stars_gain
      when "repos_most_starred"
        repos_most_starred
      else
        []
      end

      lb = Leaderboard.find_or_initialize_by(kind: kind, window: window, as_of: as_of)
      lb.entries = entries
      lb.save!

      StructuredLogger.info(message: "leaderboard_computed", kind: kind, window: window, as_of: as_of, count: entries.size) if defined?(StructuredLogger)

      success(lb)
    rescue StandardError => e
      StructuredLogger.error(message: "leaderboard_compute_failed", kind: kind, window: window, error: e.message) if defined?(StructuredLogger)
      failure(e)
    end

    private
    attr_reader :kind, :window, :as_of

    def range_days
      case window
      when "7d" then 7
      when "30d" then 30
      when "90d" then 90
      else nil
      end
    end

    def followers_total
      Profile.order(followers: :desc).limit(100).pluck(:login, :followers).map do |login, followers|
        { login: login, value: followers }
      end
    end

    def followers_gain
      days = range_days || 30
      # If we add a history table later, compute true delta. For now, approximate using `profile_activities.last_active` recency weight.
      Profile.order(followers: :desc).limit(100).pluck(:login, :followers, :last_synced_at).map do |login, followers, synced_at|
        weight = synced_at && synced_at > days.days.ago ? 1.0 : 0.7
        { login: login, value: (followers * weight).to_i, extra: { recency_weight: weight } }
      end
    end

    def stars_total
      # Sum stars across known repositories (top + pinned + active)
      rows = Profile.joins(:profile_repositories).group("profiles.login").sum("profile_repositories.stargazers_count")
      rows.sort_by { |_, sum| -sum }.first(100).map { |login, sum| { login: login, value: sum } }
    end

    def stars_gain
      days = range_days || 30
      # Without per-repo star history, approximate by recent updates as a proxy for momentum
      rows = Profile.joins(:profile_repositories)
        .where("profile_repositories.github_updated_at > ?", days.days.ago)
        .group("profiles.login").sum("profile_repositories.stargazers_count")
      rows.sort_by { |_, sum| -sum }.first(100).map { |login, sum| { login: login, value: sum, extra: { window_days: days } } }
    end

    def repos_most_starred
      ProfileRepository.order(stargazers_count: :desc).limit(100).map do |repo|
        { login: repo.profile.login, value: repo.stargazers_count, extra: { repo: repo.full_name || repo.name } }
      end
    end
  end
end
