# Configure URL options for Active Storage and route helpers in background jobs
# Uses APP_HOST (e.g., http://localhost:3000) to construct absolute URLs when needed.

begin
  host_env = ENV["APP_HOST"].presence || "http://localhost:3000"
  require "uri"
  uri = URI.parse(host_env)

  default_opts = {}
  default_opts[:host] = uri.host if uri.host
  default_opts[:protocol] = uri.scheme if uri.scheme
  default_opts[:port] = uri.port if uri.port && ![ 80, 443 ].include?(uri.port)

  if default_opts[:host].present?
    Rails.application.routes.default_url_options = default_opts
    if defined?(ActiveStorage::Current)
      ActiveStorage::Current.url_options = default_opts
    end
  end
rescue StandardError
  # best-effort; do not crash boot if APP_HOST is malformed
end
