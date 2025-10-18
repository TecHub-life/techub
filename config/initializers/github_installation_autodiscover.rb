# Attempt to auto-discover and cache the GitHub App installation id at boot.
# Safe/no-op on failure or when credentials are missing. Controlled by env flag.
# Disable by default in test environment to avoid real HTTP calls during CI.

default_flag = Rails.env.test? ? "0" : "1"
if ENV.fetch("GITHUB_AUTODISCOVER_ON_BOOT", default_flag).to_s.downcase.in?([ "1", "true", "yes" ]) && defined?(Rails)
  Rails.application.config.to_prepare do
    begin
      jwt = Github::AppAuthenticationService.call
      next if jwt.respond_to?(:failure?) && jwt.failure?
      discovered = Github::FindInstallationService.call
      if discovered.respond_to?(:success?) && discovered.success?
        id = discovered.value[:id]
        Rails.cache.write("github.installation_id.override", id, expires_in: 7.days)
      end
    rescue StandardError
      # ignore: best-effort discovery, avoid breaking boot
    end
  end
end
