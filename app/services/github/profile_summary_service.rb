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

      payload = build_payload(user, repos)

      success(payload)
    rescue Octokit::NotFound => e
      failure(e)
    end

    private

    attr_reader :login, :client

    def fetch_client
      Github::AppClientService.call
    end

    def build_payload(user, repos)
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
        languages: language_breakdown
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
        followers: user[:followers],
        following: user[:following],
        public_repos: user[:public_repos],
        public_gists: user[:public_gists],
        created_at: user[:created_at]
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
