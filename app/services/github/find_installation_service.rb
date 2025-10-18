module Github
  class FindInstallationService < ApplicationService
    def call
      jwt = Github::AppAuthenticationService.call
      return jwt if jwt.failure?

      client = Octokit::Client.new(bearer_token: jwt.value)
      # Octokit may not expose app_installations depending on version; call the endpoint directly
      installations = client.get("/app/installations")

      # Choose the first available installation for this App.
      chosen = installations.first

      return failure(StandardError.new("No GitHub App installations found")) unless chosen

      success({ id: chosen[:id], account_login: chosen.dig(:account, :login) })
    rescue Octokit::Error => e
      failure(e)
    end
  end
end
