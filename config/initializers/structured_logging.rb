Rails.application.configure do
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = proc do |severity, time, progname, msg|
    payload = case msg
    when String
                { message: msg }
    when Hash
                msg
    else
                { message: msg.inspect }
    end

    # Correlate logs with OpenTelemetry traces when available
    trace_id = nil
    span_id = nil
    begin
      require "opentelemetry-api"
      span = OpenTelemetry::Trace.current_span
      ctx = span&.context
      if ctx && ctx.valid?
        trace_id = ctx.trace_id.unpack1("H*") rescue nil
        span_id = ctx.span_id.unpack1("H*") rescue nil
      end
    rescue LoadError
      # OTEL not installed; skip correlation fields
    rescue StandardError
    end

    base = {
      ts: time.utc.iso8601(3),
      level: severity,
      request_id: Current.request_id,
      job_id: Current.job_id,
      app_version: (ENV["APP_VERSION"].presence || ENV["GIT_SHA"].presence),
      user_id: Current.user_id,
      ip: Current.ip,
      ua: Current.user_agent,
      path: Current.path,
      method: Current.method,
      trace_id: trace_id,
      span_id: span_id,
      _time: time.utc.iso8601(3)
    }

    (base.merge(payload)).to_json + "\n"
  end

  config.logger = ActiveSupport::TaggedLogging.new(logger)
  config.log_tags = [ :request_id ]
end

module StructuredLogger
  module_function

  def info(message_or_hash = nil, **extra)
    emit(:info, message_or_hash, extra)
  end

  def warn(message_or_hash = nil, **extra)
    emit(:warn, message_or_hash, extra)
  end

  def error(message_or_hash = nil, **extra)
    emit(:error, message_or_hash, extra)
  end

  def debug(message_or_hash = nil, **extra)
    emit(:debug, message_or_hash, extra)
  end

  def emit(level, message_or_hash, extra)
    # Allow callers to force Axiom forwarding (e.g., explicit smoke tests)
    extras = (extra || {}).dup
    force_axiom = ActiveModel::Type::Boolean.new.cast(extras.delete(:force_axiom)) rescue false

    base = case message_or_hash
    when String
      { message: message_or_hash }
    when Hash
      message_or_hash
    else
      { message: message_or_hash.inspect }
    end
    payload = entry(level).merge(base).merge(extras) rescue base.merge(extras)
    # Primary sink: Rails logger (JSON to STDOUT)
    Rails.logger.public_send(level, payload)

    # Optional: Axiom sink (no-op unless configured)
    cred_token = (Rails.application.credentials.dig(:axiom, :token) rescue nil)
    cred_dataset = (Rails.application.credentials.dig(:axiom, :dataset) rescue nil)
    axiom_token = cred_token.presence || ENV["AXIOM_TOKEN"]
    axiom_dataset = cred_dataset.presence || ENV["AXIOM_DATASET"]
    # Forward in production by default, or when explicitly enabled via AXIOM_ENABLED=1.
    # Always allow an explicit disable via AXIOM_DISABLE=1.
    enabled_env = (Rails.env.production? || ENV["AXIOM_ENABLED"] == "1")
    forwarding = enabled_env && ENV["AXIOM_DISABLE"] != "1"
    if forwarding && axiom_token.present? && axiom_dataset.present?
      deliver = proc do
        begin
          require "faraday"
          conn = Faraday.new(url: "https://api.axiom.co") do |f|
            f.request :retry
            f.response :raise_error
            f.adapter Faraday.default_adapter
          end
          conn.headers["Authorization"] = "Bearer #{axiom_token}"
          # Use v1 ingest API
          conn.post("/v1/datasets/#{axiom_dataset}/ingest") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = [ payload ].to_json
          end
        rescue StandardError => e
          warn "Axiom forward failed: #{e.class}: #{e.message}" if ENV["AXIOM_DEBUG"] == "1"
        end
      end
      # Synchronous when forced to guarantee delivery before process exits
      force_axiom ? deliver.call : Thread.new { deliver.call }
    elsif ENV["AXIOM_DEBUG"] == "1"
      warn "Axiom forward skipped (forwarding=#{forwarding}, token_present=#{axiom_token.present?}, dataset_present=#{axiom_dataset.present?})"
    end
  end

  def entry(level)
    {
      ts: Time.now.utc.iso8601(3),
      level: level.to_s.upcase,
      request_id: Current.request_id,
      job_id: Current.job_id,
      app_version: (ENV["APP_VERSION"].presence || ENV["GIT_SHA"].presence),
      user_id: Current.user_id,
      ip: Current.ip,
      ua: Current.user_agent,
      path: Current.path,
      method: Current.method
    }
  end
end
