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
          Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: repos)
          trace(:completed, count: repos.size)
          success_with_context(true, metadata: { ingested: repos.size })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end
      end
    end
  end
end
