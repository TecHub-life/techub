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

      # Resolve installation id: prefer configured/cached, else auto-discover
      inst_id = installation_id
      if inst_id.blank? || inst_id.to_i <= 0
        discovered = Github::FindInstallationService.call
        return discovered if discovered.failure?
        inst_id = discovered.value[:id]
        Rails.cache.write("github.installation_id.override", inst_id, expires_in: 1.day) if defined?(Rails)
      end

      # Only pass permissions if explicitly set, otherwise GitHub may return 500
      token_response = create_token(client, inst_id.to_i, permissions)

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

        token_response = create_token(client, new_id.to_i, permissions)
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
