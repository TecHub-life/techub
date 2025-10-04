module Profiles
  class SyncFromGithub < ApplicationService
    def initialize(login:)
      @login = login
    end

    def call
      result = Github::ProfileSummaryService.call(login: login)
      return result if result.failure?

      payload = result.value

      profile = Profile.find_or_initialize_by(github_login: login)
      profile.assign_attributes(
        name: payload[:profile][:name],
        avatar_url: payload[:profile][:avatar_url] || build_avatar_url(payload[:profile][:login]),
        summary: payload[:summary],
        data: {
          profile: payload[:profile],
          top_repositories: payload[:top_repositories],
          languages: payload[:languages]
        },
        last_synced_at: Time.current
      )

      if profile.save
        success(profile)
      else
        failure(StandardError.new(profile.errors.full_messages.to_sentence))
      end
    end

    private

    attr_reader :login

    def build_avatar_url(login)
      "https://github.com/#{login}.png"
    end
  end
end
