module Profiles
  module Pipeline
    module Stages
      class DownloadAvatar < BaseStage
        STAGE_ID = :download_github_avatar

        def call
          payload = context.github_payload || {}
          profile_data = payload[:profile] || {}
          avatar_url = profile_data[:avatar_url].presence

          # Skip download if no avatar URL from GitHub (user has no avatar set)
          if avatar_url.blank?
            context.avatar_local_path = nil
            context.avatar_relative_path = nil
            trace(:skipped, reason: "No avatar URL from GitHub")
            return success_with_context(nil, metadata: { skipped: true })
          end

          trace(:started, avatar_url: avatar_url)
          download = GithubProfile::DownloadAvatarService.call(avatar_url: avatar_url, login: login)

          if download.success?
            relative_path = download.value
            absolute_path = build_absolute_path(relative_path)
            context.avatar_relative_path = relative_path
            context.avatar_local_path = absolute_path
            trace(:completed, local_path: absolute_path, relative_path: relative_path)
          else
            context.avatar_local_path = nil
            context.avatar_relative_path = nil
            context.avatar_relative_path = nil
            trace(:skipped, reason: download.error&.message)
            StructuredLogger.warn(
              message: "github_avatar_download_failed",
              login: login,
              error: download.error&.message
            ) if defined?(StructuredLogger)
          end

          success_with_context(
            context.avatar_local_path,
            metadata: {
              avatar_url: avatar_url,
              local_path: context.avatar_local_path,
              relative_path: context.avatar_relative_path
            }
          )
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def build_absolute_path(relative_path)
          return nil if relative_path.blank?

          cleaned = relative_path.to_s.sub(%r{\A/+}, "")
          Rails.root.join("public", cleaned).to_s
        rescue StandardError
          nil
        end
      end
    end
  end
end
