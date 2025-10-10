module Profiles
  class SyncFromGithub < ApplicationService
    def initialize(login:)
      @login = login
    end

    def call
      result = Github::ProfileSummaryService.call(login: login, client: user_octokit_client)

      if result.failure? && user_octokit_client.present?
        StructuredLogger.warn(
          message: "Profile sync via user token failed; retrying with app client",
          login: login,
          error_class: result.error.class.name,
          error: result.error.message
        )
        result = Github::ProfileSummaryService.call(login: login)
      end

      if result.failure?
        StructuredLogger.error(
          message: "Profile sync failed",
          login: login,
          error_class: result.error.class.name,
          error: result.error.message
        )
        return result
      end

      payload = result.value

      # Download and store avatar locally
      avatar_url = payload[:profile][:avatar_url] || build_avatar_url(payload[:profile][:login])
      local_avatar_path = download_avatar(avatar_url)

      # Find or create profile by github_id
      profile = Profile.find_or_initialize_by(github_id: payload[:profile][:id])

      # Update basic profile data
      profile.assign_attributes(
        login: payload[:profile][:login].to_s.downcase,
        name: payload[:profile][:name],
        avatar_url: local_avatar_path || avatar_url,
        bio: payload[:profile][:bio],
        company: payload[:profile][:company],
        location: payload[:profile][:location],
        blog: payload[:profile][:blog],
        email: payload[:profile][:email],
        twitter_username: payload[:profile][:twitter_username],
        hireable: payload[:profile][:hireable] || false,
        html_url: payload[:profile][:html_url],
        followers: payload[:profile][:followers] || 0,
        following: payload[:profile][:following] || 0,
        public_repos: payload[:profile][:public_repos] || 0,
        public_gists: payload[:profile][:public_gists] || 0,
        github_created_at: payload[:profile][:created_at],
        github_updated_at: payload[:profile][:updated_at],
        summary: payload[:summary],
        last_synced_at: Time.current
      )

      if profile.save
        # Update related data
        update_repositories(profile, payload)
        update_organizations(profile, payload)
        update_social_accounts(profile, payload)
        update_languages(profile, payload)
        update_activity(profile, payload)
        update_readme(profile, payload)

        success(profile)
      else
        error = StandardError.new(profile.errors.full_messages.to_sentence)
        StructuredLogger.error(message: "Profile sync save failed", login: login, error: error.message)
        failure(error)
      end
    end

    private

    attr_reader :login

    def build_avatar_url(login)
      "https://github.com/#{login}.png"
    end

    def download_avatar(avatar_url)
      avatar_result = Github::DownloadAvatarService.call(
        avatar_url: avatar_url,
        login: login
      )

      if avatar_result.success?
        avatar_result.value
      else
        StructuredLogger.warn(message: "Failed to download avatar", login: login, error: avatar_result.error.message)
        nil
      end
    end

    def user_octokit_client
      return @user_octokit_client if defined?(@user_octokit_client)

      user = User.find_by(login: login)
      @user_octokit_client = if user&.access_token.present?
        Octokit::Client.new(access_token: user.access_token)
      end
    end

    def update_repositories(profile, payload)
      # Clear existing repositories
      profile.profile_repositories.destroy_all

      # Add top repositories
      (payload[:top_repositories] || []).each do |repo_data|
        repo = profile.profile_repositories.create!(
          name: repo_data[:name],
          full_name: repo_data[:full_name],
          description: repo_data[:description],
          html_url: repo_data[:html_url],
          stargazers_count: repo_data[:stargazers_count] || 0,
          forks_count: repo_data[:forks_count] || 0,
          language: repo_data[:language],
          repository_type: "top",
          github_created_at: repo_data[:created_at],
          github_updated_at: repo_data[:updated_at]
        )

        # Add topics
        (repo_data[:topics] || []).each do |topic_name|
          repo.repository_topics.create!(name: topic_name)
        end
      end

      # Add pinned repositories
      (payload[:pinned_repositories] || []).each do |repo_data|
        repo = profile.profile_repositories.create!(
          name: repo_data[:name],
          full_name: repo_data[:full_name],
          description: repo_data[:description],
          html_url: repo_data[:html_url],
          stargazers_count: repo_data[:stargazers_count] || 0,
          forks_count: repo_data[:forks_count] || 0,
          language: repo_data[:language],
          repository_type: "pinned",
          github_created_at: repo_data[:created_at],
          github_updated_at: repo_data[:updated_at]
        )

        # Add topics
        (repo_data[:topics] || []).each do |topic_name|
          repo.repository_topics.create!(name: topic_name)
        end
      end

      # Add active repositories
      (payload[:active_repositories] || []).each do |repo_data|
        repo = profile.profile_repositories.create!(
          name: repo_data[:name],
          full_name: repo_data[:full_name],
          description: repo_data[:description],
          html_url: repo_data[:html_url],
          stargazers_count: repo_data[:stargazers_count] || 0,
          forks_count: repo_data[:forks_count] || 0,
          language: repo_data[:language],
          repository_type: "active",
          github_created_at: repo_data[:created_at],
          github_updated_at: repo_data[:updated_at]
        )

        # Add topics
        (repo_data[:topics] || []).each do |topic_name|
          repo.repository_topics.create!(name: topic_name)
        end
      end
    end

    def update_organizations(profile, payload)
      profile.profile_organizations.destroy_all

      (payload[:organizations] || []).each do |org_data|
        profile.profile_organizations.create!(
          login: org_data[:login],
          name: org_data[:name],
          avatar_url: org_data[:avatar_url],
          description: org_data[:description],
          html_url: org_data[:html_url]
        )
      end
    end

    def update_social_accounts(profile, payload)
      profile.profile_social_accounts.destroy_all

      (payload[:social_accounts] || []).each do |account_data|
        profile.profile_social_accounts.create!(
          provider: account_data[:provider],
          url: account_data[:url],
          display_name: account_data[:display_name]
        )
      end
    end

    def update_languages(profile, payload)
      profile.profile_languages.destroy_all

      (payload[:languages] || {}).each do |language_name, count|
        profile.profile_languages.create!(
          name: language_name,
          count: count
        )
      end
    end

    def update_activity(profile, payload)
      activity_data = payload[:recent_activity] || {}

      profile.profile_activity&.destroy

      profile.create_profile_activity!(
        total_events: activity_data[:total_events] || 0,
        event_breakdown: activity_data[:event_breakdown] || {},
        recent_repos: (activity_data[:recent_repos] || []).to_json,
        last_active: activity_data[:last_active]
      )
    end

    def update_readme(profile, payload)
      readme_content = payload[:profile_readme]

      if readme_content.present?
        profile.profile_readme&.destroy

        # Ensure content is UTF-8 encoded
        sanitized_content = readme_content.encode("UTF-8", invalid: :replace, undef: :replace)

        profile.create_profile_readme!(
          content: sanitized_content
        )
      end
    end
  end
end
