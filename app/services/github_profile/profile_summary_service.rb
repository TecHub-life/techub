module GithubProfile
  class ProfileSummaryService < ApplicationService
    def initialize(login:, client: nil)
      @login = login
      @client = client
    end

    def call
      github_client = client || fetch_client
      return github_client if github_client.is_a?(ServiceResult) && github_client.failure?

      github_client = github_client.value if github_client.is_a?(ServiceResult)

      user = github_client.user(login)
      repos = github_client.repositories(login, per_page: 100)

      # Try to fetch profile README from username/username repo
      profile_readme = fetch_profile_readme(github_client)

      # Fetch recent activity
      recent_activity = fetch_recent_activity(github_client)
      contribution_stats = fetch_contribution_stats(github_client)

      # Fetch pinned repositories
      pinned_repos = fetch_pinned_repos(github_client)

      # Fetch details about active repos
      active_repo_details = fetch_active_repo_details(github_client, recent_activity)

      # Fetch organizations
      organizations = fetch_organizations(github_client)

      # Fetch social accounts and achievements via GraphQL
      social_accounts = fetch_social_accounts(github_client)

      payload = build_payload(
        user,
        repos,
        profile_readme,
        recent_activity,
        pinned_repos,
        active_repo_details,
        organizations,
        social_accounts,
        contribution_stats
      )

      success(payload)
    rescue Octokit::NotFound => e
      failure(e)
    end

    private

    attr_reader :login, :client

    def fetch_client
      return ServiceResult.success(client) if client

      Github::ProfileClientService.call
    end

    def fetch_profile_readme(github_client)
      readme = github_client.readme("#{login}/#{login}")
      content = Base64.decode64(readme[:content])

      # Download images and update content with local paths
      result = GithubProfile::DownloadReadmeImagesService.call(
        readme_content: content,
        login: login
      )

      content = if result.success?
        result.value[:content]
      else
        content
      end

      # Fix encoding issues with smart quotes and special characters
      fix_encoding(content)
    rescue Octokit::NotFound
      nil
    end

    def fix_encoding(content)
      return nil if content.nil?

      content
        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .gsub(/[\u2018\u2019\u201B]/, "'")  # smart single quotes
        .gsub(/[\u201C\u201D\u201E]/, '"')  # smart double quotes
        .gsub(/\u2013/, "-")                # en dash
        .gsub(/\u2014/, "--")               # em dash
        .gsub(/\u2026/, "...")              # ellipsis
        .gsub(/\uFFFD/, "'")                # replacement character
        .gsub(/'{2,}/, "'")                 # multiple apostrophes to single
    end

    def fetch_recent_activity(github_client)
      events = github_client.user_events(login, per_page: 100)

      {
        total_events: events.length,
        event_breakdown: events.group_by { |e| e[:type] }.transform_values(&:count),
        recent_repos: events.map { |e| e.dig(:repo, :name) }.compact.uniq.first(10),
        last_active: events.first&.dig(:created_at)
      }
    rescue Octokit::Error
      nil
    end

    def fetch_pinned_repos(github_client)
      result = GithubProfile::FetchPinnedReposService.call(login: login, client: github_client)
      result.success? ? result.value : []
    end

    def fetch_active_repo_details(github_client, recent_activity)
      return [] unless recent_activity && recent_activity[:recent_repos].present?

      active_repos = []
      recent_activity[:recent_repos].first(5).each do |repo_full_name|
        begin
          repo = github_client.repository(repo_full_name)
          # Only include if it's a public repo
          next if repo[:private]

          active_repos << {
            name: repo[:name],
            full_name: repo[:full_name],
            description: repo[:description],
            html_url: repo[:html_url],
            stargazers_count: repo[:stargazers_count],
            forks_count: repo[:forks_count],
            language: repo[:language],
            topics: Array(repo[:topics]),
            owner_login: repo.dig(:owner, :login)
          }
    rescue Octokit::Error => e
      StructuredLogger.debug(message: "Could not fetch active repo", repo: repo_full_name, error: e.message)
          next
        end
      end

      active_repos
    end

    def fetch_organizations(github_client)
      orgs = github_client.organizations(login)
      orgs.map do |org|
        {
          login: org[:login],
          name: org[:name],
          avatar_url: org[:avatar_url],
          description: org[:description],
          html_url: "https://github.com/#{org[:login]}"
        }
      end
    rescue Octokit::Error => e
      StructuredLogger.debug(message: "Could not fetch organizations", login: login, error: e.message)
      []
    end

    def fetch_contribution_stats(github_client)
      query = <<~GRAPHQL
        query($login: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $login) {
            contributionsCollection(from: $from, to: $to) {
              totalContributions
              totalCommitContributions
              totalPullRequestContributions
              totalPullRequestReviewContributions
              totalIssueContributions
              totalRepositoryContributions
              restrictedContributionsCount
              contributionCalendar {
                weeks {
                  contributionDays {
                    date
                    contributionCount
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      timeframe_end = Time.current.end_of_day.utc.iso8601
      timeframe_start = 90.days.ago.beginning_of_day.utc.iso8601

      result = github_client.post "/graphql", {
        query: query,
        variables: {
          login: login,
          from: timeframe_start,
          to: timeframe_end
        }
      }.to_json

      collection = result.dig(:data, :user, :contributionsCollection)
      return {} unless collection

      calendar_days = Array(collection.dig(:contributionCalendar, :weeks)).flat_map do |week|
        Array(week[:contributionDays])
      end

      streaks = compute_contribution_streaks(calendar_days)

      {
        "window_days" => 90,
        "total_contributions_90d" => collection[:totalContributions].to_i,
        "commit_contributions_90d" => collection[:totalCommitContributions].to_i,
        "pr_contributions_90d" => collection[:totalPullRequestContributions].to_i,
        "pr_review_contributions_90d" => collection[:totalPullRequestReviewContributions].to_i,
        "issue_contributions_90d" => collection[:totalIssueContributions].to_i,
        "repo_contributions_90d" => collection[:totalRepositoryContributions].to_i,
        "restricted_contributions_90d" => collection[:restrictedContributionsCount].to_i,
        "active_weeks_90d" => active_weeks_count(calendar_days),
        "current_streak" => streaks[:current],
        "longest_streak" => streaks[:longest]
      }
    rescue => e
      StructuredLogger.debug(message: "Could not fetch contribution stats", login: login, error: e.message) if defined?(StructuredLogger)
      {}
    end

    def compute_contribution_streaks(calendar_days)
      return { current: 0, longest: 0 } if calendar_days.blank?

      days = calendar_days.map do |day|
        {
          date: Date.parse(day[:date].to_s),
          count: day[:contributionCount].to_i
        } rescue nil
      end.compact.sort_by { |entry| entry[:date] }

      return { current: 0, longest: 0 } if days.empty?

      longest = 0
      current = 0
      current_streak = 0
      previous_date = nil

      days.each do |entry|
        if entry[:count] > 0 && (!previous_date || entry[:date] == previous_date + 1)
          current_streak += 1
        elsif entry[:count] > 0
          current_streak = 1
        else
          current_streak = 0
        end

        longest = [ longest, current_streak ].max

        previous_date = entry[:date]
      end

      # Compute current streak by walking backwards from last day
      current = 0
      prev_date = nil
      days.reverse_each do |entry|
        break if entry[:count] <= 0
        if prev_date.nil? || entry[:date] == prev_date - 1
          current += 1
          prev_date = entry[:date]
        else
          break
        end
      end

      { current: current, longest: longest }
    end

    def active_weeks_count(calendar_days)
      return 0 if calendar_days.blank?

      weeks = calendar_days.group_by do |day|
        date = day[:date].to_s
        Date.parse(date).cweek rescue nil
      end

      weeks.count do |_week, days|
        Array(days).any? { |d| d[:contributionCount].to_i.positive? }
      end
    rescue
      0
    end

    def fetch_social_accounts(github_client)
      query = <<~GRAPHQL
        query($login: String!) {
          user(login: $login) {
            socialAccounts(first: 10) {
              nodes {
                provider
                url
                displayName
              }
            }
          }
        }
      GRAPHQL

      result = github_client.post "/graphql", { query: query, variables: { login: login } }.to_json
      accounts = result.dig(:data, :user, :socialAccounts, :nodes) || []

      accounts.map do |account|
        {
          provider: account[:provider],
          url: account[:url],
          display_name: account[:displayName]
        }
      end
    rescue => e
      StructuredLogger.debug(message: "Could not fetch social accounts", login: login, error: e.message)
      []
    end

    def build_payload(user, repos, profile_readme, recent_activity, pinned_repos, active_repo_details, organizations, social_accounts, contribution_stats)
      top_repositories = repos
        .reject { |repo| repo[:fork] }
        .sort_by { |repo| -repo[:stargazers_count].to_i }
        .first(5)
        .map { |repo| serialize_repository(repo) }

      language_breakdown = repos
        .map { |repo| repo[:language] }
        .compact
        .tally
        .sort_by { |_language, count| -count }
        .to_h

      profile = serialize_user(user)
      summary = build_summary(profile, top_repositories, language_breakdown)

      {
        profile: profile,
        summary: summary,
        top_repositories: top_repositories,
        pinned_repositories: pinned_repos,
        active_repositories: active_repo_details,
        organizations: organizations,
        social_accounts: social_accounts,
        languages: language_breakdown,
        profile_readme: profile_readme,
        recent_activity: merge_activity_payload(recent_activity, contribution_stats)
      }
    end

    def merge_activity_payload(recent_activity, contribution_stats)
      payload = recent_activity.present? ? recent_activity.deep_dup : {}
      payload[:contribution_stats] = contribution_stats if contribution_stats.present?
      payload.presence
    end

    def serialize_user(user)
      {
        id: user[:id],
        login: user[:login],
        name: user[:name],
        avatar_url: user[:avatar_url],
        bio: user[:bio],
        company: user[:company],
        location: user[:location],
        blog: user[:blog],
        email: user[:email],
        twitter_username: user[:twitter_username],
        hireable: user[:hireable],
        html_url: user[:html_url],
        followers: user[:followers],
        following: user[:following],
        public_repos: user[:public_repos],
        public_gists: user[:public_gists],
        created_at: user[:created_at],
        updated_at: user[:updated_at]
      }
    end

    def serialize_repository(repo)
      {
        name: repo[:name],
        description: repo[:description],
        html_url: repo[:html_url],
        stargazers_count: repo[:stargazers_count],
        forks_count: repo[:forks_count],
        language: repo[:language],
        topics: Array(repo[:topics])
      }
    end

    def build_summary(profile, top_repositories, language_breakdown)
      name = profile[:name] || profile[:login]
      top_repo = top_repositories.first
      dominant_languages = language_breakdown.keys.take(3)

      summary_parts = [
        "#{name} ships in public with #{profile[:public_repos]} repositories and #{profile[:followers]} followers."
      ]

      if top_repo
        summary_parts << "Top project #{top_repo[:name]} has #{top_repo[:stargazers_count]} stars and focuses on #{top_repo[:language] || 'multiple languages'}."
      end

      if dominant_languages.any?
        summary_parts << "Frequent languages: #{dominant_languages.join(', ')}."
      end

      if profile[:bio].present?
        summary_parts << "Bio: #{profile[:bio]}"
      end

      summary_parts.join(" ")
    end
  end
end
