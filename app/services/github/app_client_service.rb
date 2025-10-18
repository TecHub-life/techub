module Github
  class AppClientService < ApplicationService
    def initialize(installation_id: Github::Configuration.installation_id, permissions: nil)
      @installation_id = installation_id
      @permissions = permissions
    end

    def call
      token_result = Github::InstallationTokenService.call(installation_id: installation_id, permissions: permissions)
      if token_result.failure?
        # Fallback: allow unauthenticated client for public data when installation token isn't available
        # This keeps profile sync functional for public endpoints even if the GitHub App installation id is invalid
        fallback_client = Octokit::Client.new
        return success(fallback_client, metadata: { fallback: "unauthenticated" })
      end

      token_payload = token_result.value
      client = Octokit::Client.new(access_token: token_payload[:token])
      success(client, metadata: { expires_at: token_payload[:expires_at] })
    end

    private

    attr_reader :installation_id, :permissions
  end
end
