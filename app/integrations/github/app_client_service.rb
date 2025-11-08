module Github
  class AppClientService < ApplicationService
    def initialize(installation_id: Github::Configuration.installation_id, permissions: nil)
      @installation_id = installation_id
      @permissions = permissions
    end

    def call
      # 1) Authenticate as the App (JWT)
      jwt = Github::AppAuthenticationService.call
      return jwt if jwt.failure?

      bearer_client = Octokit::Client.new(bearer_token: jwt.value)

      # 2) Require configured installation id (no discovery)
      inst_id = installation_id
      return failure(StandardError.new("Missing github installation_id")) if inst_id.blank? || inst_id.to_i <= 0

      # 3) Create installation token
      token_response = create_installation_token(bearer_client, inst_id.to_i, permissions)

      # 4) Return an authenticated Octokit client
      client = Octokit::Client.new(access_token: token_response[:token])
      success(client, metadata: { expires_at: token_response[:expires_at] })
    rescue Octokit::NotFound => e
      failure(e)
    rescue Octokit::Error => e
      failure(e)
    end

    private

    attr_reader :installation_id, :permissions

    def create_installation_token(client, inst_id, permissions)
      if permissions.present?
        client.create_app_installation_access_token(inst_id, permissions: permissions)
      else
        client.create_app_installation_access_token(inst_id)
      end
    end
  end
end
