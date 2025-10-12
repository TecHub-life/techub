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

      octo = client || Github::AppClientService.call.value
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

      success(created)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :profile, :repo_full_names, :client
  end
end
