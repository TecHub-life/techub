module Profiles
  class IngestSubmittedRepositoriesService < ApplicationService
    def initialize(profile:, repo_full_names: [], client: nil)
      @profile = profile
      @repo_full_names = Array(repo_full_names).map(&:to_s).reject(&:blank?).uniq.first(4)
      @client = client
    end

    def call
      return failure(StandardError.new("no_profile")) unless profile.is_a?(::Profile)
      return success([]) if repo_full_names.empty?

      client_result = resolve_client
      return client_result if client_result.failure?
      octo = client_result.value
      created = []

      repo_full_names.each do |full_name|
        begin
          repo = octo.repository(full_name)
          topics = (repo.respond_to?(:topics) && repo.topics) || []

          pr = profile.profile_repositories.find_or_initialize_by(full_name: repo.full_name, repository_type: "submitted")
          pr.assign_attributes(
            name: repo.name,
            description: repo.description,
            html_url: repo.html_url,
            stargazers_count: repo.stargazers_count || 0,
            forks_count: repo.forks_count || 0,
            language: repo.language,
            github_created_at: repo.created_at,
            github_updated_at: repo.updated_at
          )
          pr.save!

          # reset topics
          pr.repository_topics.destroy_all
          Array(topics).each { |t| pr.repository_topics.create!(name: t) }

          created << pr
        rescue StandardError => e
          StructuredLogger.warn(message: "failed_submitted_repo_ingest", full_name: full_name, error: e.message)
          next
        end
      end

      if created.empty?
        ServiceResult.degraded(created, metadata: { ingested: 0, reason: "no_repos_saved" })
      else
        ServiceResult.success(created, metadata: { ingested: created.size })
      end
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :profile, :repo_full_names, :client

    def resolve_client
      return ServiceResult.success(client) if client
      owner_client = owner_octokit_client
      return ServiceResult.success(owner_client, metadata: { client_source: :profile_owner }) if owner_client

      Github::AppClientService.call
    end

    def owner_octokit_client
      return @owner_client if defined?(@owner_client) && @owner_client
      return unless profile

      ownership = profile.profile_ownerships.includes(:user).detect { |po| po.is_owner? && po.user.present? }
      return unless ownership&.user

      # Force a fresh read to avoid any lazy decryption hiccups in tests
      user = begin
        ownership.user.reload
      rescue StandardError
        ownership.user
      end

      token = begin
        user&.access_token
      rescue StandardError
        nil
      end
      return unless token.present?

      @owner_client = Octokit::Client.new(access_token: token)
      # Cache for resolve_client so we don't rebuild and to avoid duplicate test assertions
      @client ||= @owner_client
      @owner_client
    rescue StandardError => e
      StructuredLogger.warn(message: "submitted_repo_owner_client_failed", profile_id: profile.id, error: e.message) if defined?(StructuredLogger)
      nil
    end
  end
end
