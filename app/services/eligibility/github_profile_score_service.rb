module Eligibility
  class GithubProfileScoreService < ApplicationService
    MIN_ACCOUNT_AGE_DAYS = 60
    RECENT_PUSH_WINDOW_MONTHS = 12
    MIN_RECENT_PUBLIC_REPOS = 3
    MIN_SOCIAL_PROOF = 3
    MIN_RECENT_EVENTS = 5
    DEFAULT_THRESHOLD = 3

    def initialize(profile:, repositories: [], recent_activity: nil, pinned_repositories: [], profile_readme: nil, organizations: [], threshold: DEFAULT_THRESHOLD, as_of: Time.current)
      @profile = profile || {}
      @repositories = Array(repositories)
      @recent_activity = recent_activity || {}
      @pinned_repositories = Array(pinned_repositories)
      @profile_readme = profile_readme
      @organizations = Array(organizations)
      @threshold = threshold
      @as_of = as_of || Time.current
    end

    def call
      signals = {
        account_age: account_age_signal,
        repository_activity: repository_activity_signal,
        social_proof: social_proof_signal,
        meaningful_profile: meaningful_profile_signal,
        recent_activity: recent_activity_signal
      }

      score = signals.values.count { |signal| signal[:met] }

      success(
        {
          score: score,
          threshold: threshold,
          eligible: score >= threshold,
          signals: signals
        }
      )
    end

    private

    attr_reader :profile, :repositories, :recent_activity, :pinned_repositories, :profile_readme, :organizations, :threshold, :as_of

    def account_age_signal
      created_at = fetch_time(profile, :created_at)
      return signal(false, "Account creation date missing") unless created_at

      age_days = (as_of.to_date - created_at.to_date).to_i
      if age_days >= MIN_ACCOUNT_AGE_DAYS
        signal(true, "Account age #{age_days} days meets minimum of #{MIN_ACCOUNT_AGE_DAYS} days")
      else
        signal(false, "Account age #{age_days} days below minimum of #{MIN_ACCOUNT_AGE_DAYS} days")
      end
    end

    def repository_activity_signal
      qualifying_repos = repositories.select { |repo| qualifies_as_recent_public_repo?(repo) }

      if qualifying_repos.size >= MIN_RECENT_PUBLIC_REPOS
        signal(true, "#{qualifying_repos.size} public repos with pushes in last #{RECENT_PUSH_WINDOW_MONTHS} months")
      else
        signal(false, "Only #{qualifying_repos.size} public repos with pushes in last #{RECENT_PUSH_WINDOW_MONTHS} months (need #{MIN_RECENT_PUBLIC_REPOS})")
      end
    end

    def qualifies_as_recent_public_repo?(repo)
      return false if truthy?(fetch_value(repo, :private))
      return false if truthy?(fetch_value(repo, :archived))
      return false unless owned_repository?(repo)

      pushed_at = fetch_time(repo, :pushed_at)
      return false unless pushed_at

      pushed_at >= RECENT_PUSH_WINDOW_MONTHS.months.ago(as_of)
    end

    def owned_repository?(repo)
      owner_login = deduced_owner_login(repo)
      return true if owner_login.blank?

      owner_login.casecmp(profile_login).zero? || organization_logins.include?(owner_login.downcase)
    end

    def deduced_owner_login(repo)
      owner = fetch_value(repo, :owner)
      if owner.is_a?(Hash)
        owner[:login] || owner["login"]
      else
        fetch_value(repo, :owner_login)
      end
    end

    def profile_login
      fetch_value(profile, :login).to_s
    end

    def organization_logins
      @organization_logins ||= organizations.filter_map { |org| fetch_value(org, :login)&.downcase }
    end

    def social_proof_signal
      followers = fetch_value(profile, :followers).to_i
      following = fetch_value(profile, :following).to_i

      if followers >= MIN_SOCIAL_PROOF || following >= MIN_SOCIAL_PROOF
        signal(true, "Followers #{followers}, following #{following} (threshold #{MIN_SOCIAL_PROOF})")
      else
        signal(false, "Followers #{followers}, following #{following} below threshold #{MIN_SOCIAL_PROOF}")
      end
    end

    def meaningful_profile_signal
      if present?(fetch_value(profile, :bio)) || present?(profile_readme) || pinned_repositories.any?
        signal(true, "Meaningful profile context detected (bio/readme/pinned repos)")
      else
        signal(false, "No bio, README, or pinned repositories detected")
      end
    end

    def recent_activity_signal
      total_events = fetch_value(recent_activity, :total_events).to_i

      if total_events >= MIN_RECENT_EVENTS
        signal(true, "#{total_events} public events in the past 90 days")
      else
        signal(false, "#{total_events} public events in the past 90 days (need #{MIN_RECENT_EVENTS})")
      end
    end

    def fetch_value(source, key)
      return nil unless source.respond_to?(:[])

      source[key] || source[key.to_s]
    end

    def fetch_time(source, key)
      raw = fetch_value(source, key)
      return if raw.blank?

      raw.respond_to?(:to_time) ? raw.to_time : Time.zone.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def signal(met, detail)
      { met: met, detail: detail }
    end

    def truthy?(value)
      value == true || value.to_s.casecmp("true").zero?
    end

    def present?(value)
      value.respond_to?(:present?) ? value.present? : value && !value.to_s.strip.empty?
    end
  end
end
