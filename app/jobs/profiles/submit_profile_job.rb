module Profiles
  class SubmitProfileJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login, actor_id, submitted_scrape_url: nil, submitted_repositories: nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      login = login.to_s.downcase.strip
      actor = User.find_by(id: actor_id)
      unless login.present? && actor
        StructuredLogger.warn(
          { message: "submit_job_skipped", service: self.class.name, login: login, actor_id: actor_id, reason: "invalid_parameters" },
          component: "job",
          event: "pipeline.submit_job_skipped",
          ops_details: { job: self.class.name, login: login, actor_id: actor_id, reason: "invalid_parameters" }
        )
        return
      end

      sync = Profiles::SyncFromGithub.call(login: login)
      unless sync.success?
        StructuredLogger.error(
          { message: "submit_job_sync_failed", service: self.class.name, login: login, actor_id: actor_id, error: sync.error&.message, metadata: sync.metadata },
          component: "job",
          event: "pipeline.submit_job_sync_failed",
          ops_details: { job: self.class.name, login: login, actor_id: actor_id, error: sync.error&.message }
        )
        return
      end

      profile = sync.value
      sync_meta = sync.metadata || {}
      persisted = Profile.for_login(profile.login).first || profile

      # Link or claim ownership using policy (idempotent)
      claim = Profiles::ClaimOwnershipService.call(user: actor, profile: persisted)
      if claim.failure?
        StructuredLogger.warn(
          { message: "submit_job_claim_failed", service: self.class.name, login: login, actor_id: actor_id, error: claim.error&.message },
          component: "job",
          event: "pipeline.submit_job_claim_failed",
          ops_details: { job: self.class.name, login: login, actor_id: actor_id, error: claim.error&.message }
        )
      end

      # Persist optional manual inputs when provided
      url = submitted_scrape_url.to_s.strip
      persisted.update!(submitted_scrape_url: url) if url.present?

      normalized_repos(submitted_repositories).each do |full_name|
        owner, repo = full_name.split("/", 2)
        next if owner.blank? || repo.blank?
        pr = persisted.profile_repositories.find_or_initialize_by(full_name: "#{owner}/#{repo}", repository_type: "submitted")
        pr.name ||= repo
        pr.save!
      end

      # Enqueue pipeline job and mark status
      persisted.update_columns(submitted_at: Time.current, last_pipeline_status: "queued", last_pipeline_error: nil)

      Profiles::GeneratePipelineJob.perform_later(persisted.login, trigger_source: "submit_profile_job")
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i
      StructuredLogger.info(
        {
          message: "submit_job_enqueue",
          service: self.class.name,
          login: persisted.login,
          actor_id: actor_id,
          submitted_url: url.presence,
          submitted_repo_count: normalized_repos(submitted_repositories).size,
          sync_run_id: sync_meta[:run_id],
          duration_ms: duration_ms
        },
        component: "job",
        event: "pipeline.submit_job_enqueue",
        ops_details: {
          job: self.class.name,
          login: persisted.login,
          actor_id: actor_id,
          sync_run_id: sync_meta[:run_id],
          duration_ms: duration_ms
        }
      )
    end

    private

    def normalized_repos(submitted_repositories)
      Array(submitted_repositories)
        .compact
        .map(&:to_s)
        .map(&:strip)
        .reject(&:blank?)
        .first(4)
    end
  end
end
