module Github
  class AppClientService < ApplicationService
    def initialize(installation_id: Github::Configuration.installation_id, permissions: nil)
      @installation_id = installation_id
      @permissions = permissions
    end

    def call
      token_result = Github::InstallationTokenService.call(installation_id: installation_id, permissions: permissions)
      return token_result if token_result.failure?

      token_payload = token_result.value
      client = Octokit::Client.new(access_token: token_payload[:token])
      success(client, metadata: { expires_at: token_payload[:expires_at] })
    end

    private

    attr_reader :installation_id, :permissions
  end
end
