module Github
  class InstallationTokenService < ApplicationService
    def initialize(installation_id: Github::Configuration.installation_id, permissions: nil)
      @installation_id = installation_id
      @permissions = permissions
    end

    def call
      jwt = Github::AppAuthenticationService.call
      return jwt if jwt.failure?

      client = Octokit::Client.new(bearer_token: jwt.value)

      # If no installation_id configured, fail fast to avoid accidental API calls
      inst_id = installation_id
      return failure(StandardError.new("GitHub installation_id missing")) if inst_id.blank?

      # Only pass permissions if explicitly set, otherwise GitHub may return 500
      token_response = create_token(client, inst_id, permissions)

      success(
        {
          token: token_response[:token],
          expires_at: token_response[:expires_at],
          permissions: token_response[:permissions]
        }
      )
    rescue Octokit::NotFound => e
      # Installation ID likely changed or is invalid; try to auto-discover
      begin
        discovered = Github::FindInstallationService.call
        return failure(e) if discovered.failure?

        new_id = discovered.value[:id]
        StructuredLogger.warn(message: "github_installation_not_found_retrying", old_installation_id: installation_id, new_installation_id: new_id, account: discovered.value[:account_login]) if defined?(StructuredLogger)

        # Cache the discovered installation id to avoid repeated discovery
        Rails.cache.write("github.installation_id.override", new_id, expires_in: 1.day) if defined?(Rails)

        token_response = create_token(client, new_id, permissions)
        success({ token: token_response[:token], expires_at: token_response[:expires_at], permissions: token_response[:permissions], installation_id: new_id })
      rescue Octokit::Error => e2
        failure(e2)
      end
    rescue Octokit::Error => e
      failure(e)
    end

    private

    attr_reader :installation_id, :permissions

    def create_token(client, inst_id, permissions)
      if permissions.present?
        client.create_app_installation_access_token(inst_id, permissions: permissions)
      else
        client.create_app_installation_access_token(inst_id)
      end
    end
  end
end
