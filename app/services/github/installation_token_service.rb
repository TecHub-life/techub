module Github
  class InstallationTokenService < ApplicationService
    def initialize(installation_id: Github::Configuration.installation_id, permissions: nil)
      @installation_id = installation_id
      @permissions = permissions
    end

    def call
      return failure(StandardError.new("GitHub installation id is not configured")) if installation_id.blank?

      jwt = Github::AppAuthenticationService.call
      return jwt if jwt.failure?

      client = Octokit::Client.new(bearer_token: jwt.value)

      # Only pass permissions if explicitly set, otherwise GitHub may return 500
      token_response = if permissions.present?
        client.create_app_installation_access_token(installation_id, permissions: permissions)
      else
        client.create_app_installation_access_token(installation_id)
      end

      success(
        {
          token: token_response[:token],
          expires_at: token_response[:expires_at],
          permissions: token_response[:permissions]
        }
      )
    rescue Octokit::Error => e
      failure(e)
    end

    private

    attr_reader :installation_id, :permissions
  end
end
