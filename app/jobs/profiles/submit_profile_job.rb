module Profiles
  class SubmitProfileJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login, actor_id, submitted_scrape_url: nil, submitted_repositories: nil)
      login = login.to_s.downcase.strip
      actor = User.find_by(id: actor_id)
      return unless login.present? && actor

      sync = Profiles::SyncFromGithub.call(login: login)
      return unless sync.success?
      profile = sync.value
      persisted = Profile.for_login(profile.login).first || profile

      # Link or claim ownership using policy (idempotent)
      Profiles::ClaimOwnershipService.call(user: actor, profile: persisted)

      # Persist optional manual inputs when provided
      url = submitted_scrape_url.to_s.strip
      persisted.update!(submitted_scrape_url: url) if url.present?

      Array(submitted_repositories).compact.map(&:to_s).map(&:strip).reject(&:blank?).first(4).each do |full_name|
        owner, repo = full_name.split("/", 2)
        next if owner.blank? || repo.blank?
        pr = persisted.profile_repositories.find_or_initialize_by(full_name: "#{owner}/#{repo}", repository_type: "submitted")
        pr.name ||= repo
        pr.save!
      end

      # Enqueue pipeline job and mark status
      persisted.update_columns(submitted_at: Time.current, last_pipeline_status: "queued", last_pipeline_error: nil)

      Profiles::GeneratePipelineJob.perform_later(persisted.login)
    end
  end
end
