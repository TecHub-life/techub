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
          trace(:completed)
          success_with_context(context.github_payload, metadata: { payload: :github })
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
      end
    end
  end
end
