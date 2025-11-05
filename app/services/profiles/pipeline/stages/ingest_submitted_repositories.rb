module Profiles
  module Pipeline
    module Stages
      class IngestSubmittedRepositories < BaseStage
        STAGE_ID = :ingest_submitted_repositories

        def call
          profile = context.profile
          return success_with_context(true, metadata: { skipped: true }) unless profile

          repos = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name).compact
          if repos.empty?
            trace(:skipped)
            return success_with_context(true, metadata: { skipped: true })
          end

          trace(:started, count: repos.size)
          result = Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: repos)

          if result.failure?
            trace(:failed, error: result.error&.message)
            return failure_with_context(result.error || StandardError.new("repo_ingest_failed"), metadata: safe_metadata(result))
          end

          trace(:completed, count: repos.size)
          metadata = { ingested: repos.size }.merge(safe_metadata(result) || {})
          if result.degraded?
            degraded_with_context(true, metadata: metadata.merge(reason: metadata[:reason] || "partial_ingest"))
          else
            success_with_context(true, metadata: metadata)
          end
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end
      end
    end
  end
end
