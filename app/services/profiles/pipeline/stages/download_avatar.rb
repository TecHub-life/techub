module Profiles
  module Pipeline
    module Stages
      class DownloadAvatar < BaseStage
        STAGE_ID = :download_github_avatar

        def call
          payload = context.github_payload || {}
          profile_data = payload[:profile] || {}
          avatar_url = profile_data[:avatar_url].presence || default_avatar_url(profile_data[:login] || login)

          trace(:started, avatar_url: avatar_url)
          download = Github::DownloadAvatarService.call(avatar_url: avatar_url, login: login)

          if download.success?
            context.avatar_local_path = download.value
            trace(:completed, local_path: download.value)
          else
            context.avatar_local_path = nil
            trace(:skipped, reason: download.error&.message)
            StructuredLogger.warn(
              message: "github_avatar_download_failed",
              login: login,
              error: download.error&.message
            ) if defined?(StructuredLogger)
          end

          success_with_context(context.avatar_local_path, metadata: { avatar_url: avatar_url })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def default_avatar_url(login)
          "https://github.com/#{login}.png"
        end
      end
    end
  end
end
