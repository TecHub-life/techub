require "cgi"

module AppConfig
  module_function

  def reload!
    @env = nil
    @app = nil
    @axiom = nil
  end

  def environment
    @env ||= normalize_env(raw_env)
  end
  alias env environment

  def app
    @app ||= begin
      hosts = resolve_hosts
      {
        name: ENV["APP_NAME"].presence || "techub",
        env: environment,
        host: hosts.first,
        hosts: hosts,
        version: app_version
      }.freeze
    end
  end

  def app_version
    ENV["APP_VERSION"].presence || ENV["GIT_SHA"].presence
  end

  def axiom
    @axiom ||= begin
      creds = (Rails.application.credentials.dig(:axiom) rescue {}) || {}
      otel = (Rails.application.credentials.dig(:otel) rescue {}) || {}

      token = creds[:token].presence || ENV["AXIOM_TOKEN"]
      dataset = creds[:dataset].presence || ENV["AXIOM_DATASET"]
      metrics_dataset = creds[:metrics_dataset].presence || ENV["AXIOM_METRICS_DATASET"]
      org = creds[:org].presence || ENV["AXIOM_ORG"]
      base_url = creds[:base_url].presence || ENV["AXIOM_BASE_URL"] || "https://api.axiom.co"
      dataset_url = creds[:dataset_url].presence || ENV["AXIOM_DATASET_URL"]
      metrics_dataset_url = creds[:metrics_dataset_url].presence || ENV["AXIOM_METRICS_DATASET_URL"]
      traces_url = creds[:traces_url].presence || ENV["AXIOM_TRACES_URL"]
      otel_endpoint = otel[:endpoint].presence || ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]

      dataset_url ||= "https://app.axiom.co/#{org}/datasets/#{dataset}" if org.present? && dataset.present?
      metrics_dataset_url ||= "https://app.axiom.co/#{org}/datasets/#{metrics_dataset}" if org.present? && metrics_dataset.present?
      traces_url ||= org.present? ? "https://app.axiom.co/#{org}/traces" : "https://app.axiom.co/traces"
      traces_url = "#{traces_url}?service=#{CGI.escape(app[:name])}" if traces_url && app[:name].present?

      {
        token: token,
        dataset: dataset,
        metrics_dataset: metrics_dataset,
        org: org,
        base_url: base_url,
        dataset_url: dataset_url,
        metrics_dataset_url: metrics_dataset_url,
        traces_url: traces_url,
        otel_endpoint: otel_endpoint,
        allow_dataset_create: truthy?(ENV["AXIOM_ALLOW_DATASET_CREATE"]),
        auto_forward: environment == "production" || truthy?(ENV["AXIOM_ENABLED"]),
        disabled: truthy?(ENV["AXIOM_DISABLE"]),
        debug: truthy?(ENV["AXIOM_DEBUG"])
      }.freeze
    end
  end

  def axiom_forwarding(force: false)
    cfg = axiom
    token_present = cfg[:token].present?
    dataset_present = cfg[:dataset].present?

    reason =
      if cfg[:disabled]
        :disabled
      elsif !token_present
        :missing_token
      elsif !dataset_present
        :missing_dataset
      elsif force
        :forced
      elsif cfg[:auto_forward]
        :env_enabled
      else
        :env_disabled
      end

    {
      allowed: !%i[disabled missing_token missing_dataset env_disabled].include?(reason),
      reason: reason,
      force: force,
      token_present: token_present,
      dataset_present: dataset_present,
      auto_forward: cfg[:auto_forward],
      disabled: cfg[:disabled]
    }
  end

  def axiom_forwarding_enabled?(force: false)
    axiom_forwarding(force: force)[:allowed]
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) ? true : false
  end

  def normalize_env(value)
    case value.to_s.downcase
    when "production", "prod" then "production"
    when "staging" then "staging"
    when "sandbox", "test" then "sandbox"
    when "development", "dev" then "development"
    else
      Rails.env.presence || "development"
    end
  end
  private :normalize_env

  def raw_env
    ENV["APP_ENV"] || ENV["RAILS_ENV"] || ENV["NODE_ENV"]
  end
  private :raw_env

  def resolve_hosts
    hosts = (ENV["WEB_HOSTS"] || ENV["APP_HOST"]).to_s.split(",").map { |h| h.strip }.reject(&:blank?)
    hosts.presence || default_hosts
  end
  private :resolve_hosts

  def default_hosts
    default = case environment
    when "production" then "https://techub.life"
    when "staging" then ENV["APP_URL"].presence
    else
                nil
    end
    default ? [ default ] : []
  end
  private :default_hosts
end
