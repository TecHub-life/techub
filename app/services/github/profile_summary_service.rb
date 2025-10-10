module Github
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

      # Fetch pinned repositories
      pinned_repos = fetch_pinned_repos(github_client)

      # Fetch details about active repos
      active_repo_details = fetch_active_repo_details(github_client, recent_activity)

      # Fetch organizations
      organizations = fetch_organizations(github_client)

      # Fetch social accounts and achievements via GraphQL
      social_accounts = fetch_social_accounts(github_client)

      payload = build_payload(user, repos, profile_readme, recent_activity, pinned_repos, active_repo_details, organizations, social_accounts)

      success(payload)
    rescue Octokit::NotFound => e
      failure(e)
    end

    private

    attr_reader :login, :client

    def fetch_client
      Github::AppClientService.call
    end

    def fetch_profile_readme(github_client)
      readme = github_client.readme("#{login}/#{login}")
      content = Base64.decode64(readme[:content])

      # Download images and update content with local paths
      result = Github::DownloadReadmeImagesService.call(
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
      result = Github::FetchPinnedReposService.call(login: login, client: github_client)
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

    def build_payload(user, repos, profile_readme, recent_activity, pinned_repos, active_repo_details, organizations, social_accounts)
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
        recent_activity: recent_activity
      }
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
