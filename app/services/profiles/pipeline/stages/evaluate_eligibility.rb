module Profiles
  module Pipeline
    module Stages
      class EvaluateEligibility < BaseStage
        STAGE_ID = :evaluate_eligibility

        def call
          return success_with_context(true, metadata: { skipped: true }) unless FeatureFlags.enabled?(:require_profile_eligibility)

          profile = context.profile
          return failure_with_context(StandardError.new("profile_missing_for_eligibility")) unless profile

          trace(:started)
          result = Eligibility::GithubProfileScoreService.call(
            profile: eligibility_profile_payload(profile),
            repositories: eligibility_repositories(profile),
            recent_activity: { total_events: profile.profile_activity&.total_events.to_i },
            pinned_repositories: profile.profile_repositories.where(repository_type: "pinned").map { |r| { name: r.name } },
            profile_readme: profile.profile_readme&.content,
            organizations: profile.profile_organizations.map { |o| { login: o.login } }
          )

          if result.failure?
            trace(:failed, error: result.error&.message)
            return failure_with_context(result.error || StandardError.new("eligibility_failed"), metadata: { upstream: safe_metadata(result) })
          end

          context.eligibility = result.value

          if result.value[:eligible]
            trace(:completed, score: result.value[:score], threshold: result.value[:threshold])
            success_with_context(result.value)
          else
            trace(:denied, score: result.value[:score], threshold: result.value[:threshold])
            failure_with_context(StandardError.new("profile_not_eligible"), metadata: { eligibility: result.value })
          end
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def eligibility_profile_payload(profile)
          {
            login: profile.login,
            followers: profile.followers,
            following: profile.following,
            created_at: profile.github_created_at
          }
        end

        def eligibility_repositories(profile)
          profile.profile_repositories.map do |repo|
            {
              private: false,
              archived: false,
              pushed_at: repo.github_updated_at,
              owner_login: repo.full_name&.split("/")&.first || profile.login
            }
          end
        end
      end
    end
  end
end
