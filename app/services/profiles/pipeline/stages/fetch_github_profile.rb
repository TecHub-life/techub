module Profiles
  module Pipeline
    module Stages
      class FetchGithubProfile < BaseStage
        STAGE_ID = :pull_github_data

        def call
          trace(:started)
          result = Github::ProfileSummaryService.call(login: login, client: user_octokit_client)

          if result.failure? && user_octokit_client.present?
            StructuredLogger.warn(
              message: "github_profile_pull_user_client_failed",
              login: login,
              error: result.error&.message
            ) if defined?(StructuredLogger)
            trace(:fallback, via: :app_client, error: result.error&.message)
            result = Github::ProfileSummaryService.call(login: login)
          end

          if result.failure?
            trace(:failed, error: result.error&.message)
            return failure_with_context(result.error || StandardError.new("github_profile_pull_failed"), metadata: { upstream: safe_metadata(result) })
          end

          context.github_payload = result.value
          trace(:completed, summary: summary_for(result.value))
          success_with_context(context.github_payload, metadata: { payload: :github, summary: summary_for(result.value) })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def user_octokit_client
          return @user_octokit_client if defined?(@user_octokit_client)

          user = User.find_by(login: login)
          @user_octokit_client = if user&.access_token.present?
            Octokit::Client.new(access_token: user.access_token)
          end
        end

        def summary_for(payload)
          return nil unless payload.is_a?(Hash)

          profile = payload[:profile] || {}
          {
            login: profile[:login],
            followers: profile[:followers],
            public_repos: profile[:public_repos],
            public_gists: profile[:public_gists],
            organizations: Array(payload[:organizations]).size,
            top_repositories: Array(payload[:top_repositories]).size,
            pinned_repositories: Array(payload[:pinned_repositories]).size
          }.compact
        end
      end
    end
  end
end
