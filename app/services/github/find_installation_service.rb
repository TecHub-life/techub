module Github
  class FindInstallationService < ApplicationService
    def call
      jwt = Github::AppAuthenticationService.call
      return jwt if jwt.failure?

      client = Octokit::Client.new(bearer_token: jwt.value)
      # Octokit may not expose app_installations depending on version; call the endpoint directly
      installations = Array(client.get("/app/installations"))
      # Normalize to symbol keys to avoid nil lookups when Octokit returns string keys
      normalized = installations.map do |item|
        h = item.respond_to?(:to_hash) ? item.to_hash : item
        begin
          h.transform_keys { |k| k.to_s.downcase.to_sym }
        rescue
          h
        end
      end

      # Choose the first available installation for this App.
      chosen = normalized.first
      return failure(StandardError.new("No GitHub App installations found")) unless chosen

      account = chosen[:account].is_a?(Hash) ? chosen[:account] : {}
      success({ id: chosen[:id] || chosen["id"], account_login: account[:login] || account["login"] })
    rescue Octokit::Error => e
      failure(e)
    end
  end
end
