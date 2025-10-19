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

    base = {
      ts: time.utc.iso8601(3),
      level: severity,
      request_id: Current.request_id,
      user_id: Current.user_id,
      ip: Current.ip,
      ua: Current.user_agent,
      path: Current.path,
      method: Current.method
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
    payload = entry.merge(base).merge(extras) rescue base.merge(extras)
    # Primary sink: Rails logger (JSON to STDOUT)
    Rails.logger.public_send(level, payload)

    # Optional: Axiom sink (no-op unless configured)
    axiom_token = ENV["AXIOM_TOKEN"]
    axiom_dataset = ENV["AXIOM_DATASET"]
    env_flag = ActiveModel::Type::Boolean.new.cast(ENV["AXIOM_ENABLED"]) rescue false
    if (Rails.env.production? || env_flag || force_axiom) && axiom_token.present? && axiom_dataset.present?
      # Lazy, best-effort delivery; ignore network errors
      Thread.new do
        begin
          conn = Faraday.new(url: "https://api.axiom.co") do |f|
            f.request :json
            f.response :raise_error
            f.adapter Faraday.default_adapter
          end
          conn.headers["Authorization"] = "Bearer #{axiom_token}"
          conn.post("/v2/datasets/#{axiom_dataset}/ingest", [ payload ])
        rescue StandardError
          # swallow
        end
      end
    end
  end
end
