# Central application host resolution
#
# Policy:
# - Production: pin to a single canonical host. Allow ENV override if explicitly set.
# - Non-production: prefer ENV APP_HOST, fallback to localhost.

Rails.application.config.x.app_host = (
  ENV["APP_HOST"].presence || Rails.application.credentials.dig(:app, :host).presence || (Rails.env.production? ? "https://techub.life" : "http://127.0.0.1:3000")
)

# Expose a simple accessor for services/controllers
module AppHost
  def self.current
    Rails.application.config.x.app_host
  end
end

# Optionally wire default_url_options host
Rails.application.routes.default_url_options[:host] = URI.parse(AppHost.current).host rescue nil
