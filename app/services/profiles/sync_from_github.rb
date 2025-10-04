module Profiles
  class SyncFromGithub < ApplicationService
    def initialize(login:)
      @login = login
    end

    def call
      result = Github::ProfileSummaryService.call(login: login, client: user_octokit_client)

      if result.failure? && user_octokit_client.present?
        Rails.logger.warn(
          "Profile sync via user token failed for #{login}: #{result.error.class} - #{result.error.message}; retrying with app client"
        )
        result = Github::ProfileSummaryService.call(login: login)
      end

      if result.failure?
        Rails.logger.error(
          "Profile sync failed for #{login}: #{result.error.class} - #{result.error.message}"
        )
        return result
      end

      payload = result.value

      # Download and store avatar locally
      avatar_url = payload[:profile][:avatar_url] || build_avatar_url(payload[:profile][:login])
      local_avatar_path = download_avatar(avatar_url)

      profile = Profile.find_or_initialize_by(github_login: login)
      profile.assign_attributes(
        name: payload[:profile][:name],
        avatar_url: local_avatar_path || avatar_url,
        summary: payload[:summary],
        data: {
          profile: payload[:profile],
          top_repositories: payload[:top_repositories],
          pinned_repositories: payload[:pinned_repositories],
          active_repositories: payload[:active_repositories],
          organizations: payload[:organizations],
          social_accounts: payload[:social_accounts],
          languages: payload[:languages],
          profile_readme: payload[:profile_readme],
          recent_activity: payload[:recent_activity]
        },
        last_synced_at: Time.current
      )

      if profile.save
        success(profile)
      else
        error = StandardError.new(profile.errors.full_messages.to_sentence)
        Rails.logger.error("Profile sync save failed for #{login}: #{error.message}")
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
        Rails.logger.warn("Failed to download avatar for #{login}: #{avatar_result.error.message}")
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
  end
end
