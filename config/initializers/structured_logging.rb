require "thread"
require "concurrent/atomic/atomic_fixnum"
require "concurrent/atomic/atomic_reference"

module StructuredLogger
  extend self

  AXIOM_FORWARD_SKIP_KEY = :_axiom_forward_skip

  unless defined?(AXIOM_FORWARD_QUEUE)
    AXIOM_FORWARD_QUEUE = Queue.new
  end

  unless defined?(AXIOM_FORWARD_WORKER)
    AXIOM_FORWARD_WORKER = Thread.new do
      Thread.current.name = "structured_logger_axiom_forwarder" if Thread.current.respond_to?(:name=)
      loop do
        job = AXIOM_FORWARD_QUEUE.pop
        job.call
      end
    end
  end

  unless defined?(AXIOM_FORWARD_ENQUEUED)
    AXIOM_FORWARD_ENQUEUED = Concurrent::AtomicFixnum.new(0)
    AXIOM_FORWARD_DRAINED = Concurrent::AtomicFixnum.new(0)
    AXIOM_FORWARD_LAST_ERROR = Concurrent::AtomicReference.new(nil)
    AXIOM_FORWARD_LAST_ERROR_AT = Concurrent::AtomicReference.new(nil)
    AXIOM_FORWARD_LAST_DELIVERY = Concurrent::AtomicReference.new(nil)
    AXIOM_FORWARD_LAST_SKIP = Concurrent::AtomicReference.new(nil)
  end

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
    extras = (extra || {}).dup
    force_axiom = ActiveModel::Type::Boolean.new.cast(extras.delete(:force_axiom)) rescue false
    ops_context_override = extras.delete(:ops_context)
    ops_details = extras.delete(:ops_details)
    component_hint = extras.delete(:component)
    precedence_hint = extras.delete(:precedence)
    event_hint = extras.delete(:event)
    actor_hint = extras.delete(:actor)

    payload = build_payload(level, message_or_hash, extras)
    payload[:ops_context] ||= ops_context_for(
      payload,
      component_hint: component_hint,
      precedence_hint: precedence_hint,
      event_hint: event_hint,
      ops_context_override: ops_context_override,
      ops_details: ops_details,
      actor_hint: actor_hint
    )

    payload[AXIOM_FORWARD_SKIP_KEY] = true
    Rails.logger.public_send(level, payload)
    forward_to_axiom(payload, force_axiom: force_axiom)
    payload
  ensure
    payload.delete(AXIOM_FORWARD_SKIP_KEY) if payload.is_a?(Hash)
  end

  def forwarding_stats
    enqueued = AXIOM_FORWARD_ENQUEUED.value
    drained = AXIOM_FORWARD_DRAINED.value
    pending = enqueued - drained
    {
      enqueued: enqueued,
      delivered: drained,
      pending: pending.positive? ? pending : 0,
      last_delivery: AXIOM_FORWARD_LAST_DELIVERY.value,
      last_error: AXIOM_FORWARD_LAST_ERROR.value,
      last_error_at: AXIOM_FORWARD_LAST_ERROR_AT.value,
      last_skip: AXIOM_FORWARD_LAST_SKIP.value
    }
  end

  def describe_error(error)
    format_error(error)
  end

  def forward_from_logger(payload, force_axiom: false)
    forward_to_axiom(payload, force_axiom: force_axiom)
  end

  private

  def build_payload(level, message_or_hash, extras)
    base = case message_or_hash
    when String then { message: message_or_hash }
    when Hash then message_or_hash
    else
      { message: message_or_hash.inspect }
    end
    entry(level).merge(base).merge(extras)
  rescue StandardError
    entry(level).merge(base)
  end

  def entry(level)
    {
      ts: Time.now.utc.iso8601(3),
      level: level.to_s.upcase,
      request_id: Current.request_id,
      job_id: Current.job_id,
      app_version: AppConfig.app_version,
      rails_env: Rails.env,
      app_env: AppConfig.environment,
      deployment_environment: deployment_environment,
      user_id: Current.user_id,
      ip: Current.ip,
      ua: Current.user_agent,
      path: Current.path,
      method: Current.method
    }.merge(ci_metadata)
  end

  def ops_context_for(payload, component_hint:, precedence_hint:, event_hint:, ops_context_override:, ops_details:, actor_hint:)
    return ops_context_override if ops_context_override.present?

    event_name = event_hint || payload[:event] || payload[:message]
    OpsContext.build(
      event: event_name,
      component: component_hint,
      precedence: precedence_hint,
      actor: actor_hint,
      details: ops_details
    )
  end

  def forward_to_axiom(payload, force_axiom:)
    axiom_cfg = AppConfig.axiom
    forwarding = AppConfig.axiom_forwarding(force: force_axiom)
    return record_skip(forwarding) if !forwarding[:allowed]

    dataset = axiom_cfg[:dataset]
    deliver = proc do
      result = Axiom::IngestService.call(dataset: dataset, events: [ payload ])
      record_forward_result(result, dataset)
    end

    AXIOM_FORWARD_ENQUEUED.increment

    if force_axiom
      deliver.call
    else
      AXIOM_FORWARD_QUEUE << deliver
    end
  end

  def record_skip(forwarding)
    AXIOM_FORWARD_LAST_SKIP.set({
      at: Time.now.utc.iso8601(3),
      reason: forwarding[:reason],
      force: forwarding[:force],
      token_present: forwarding[:token_present],
      dataset_present: forwarding[:dataset_present]
    })
    nil
  end

  def record_forward_result(result, dataset)
    if result.success?
      AXIOM_FORWARD_DRAINED.increment
      AXIOM_FORWARD_LAST_ERROR.set(nil)
      AXIOM_FORWARD_LAST_ERROR_AT.set(nil)
      AXIOM_FORWARD_LAST_DELIVERY.set({
        at: Time.now.utc.iso8601(3),
        dataset: dataset,
        status: result.value,
        metadata: result.metadata
      })
      AXIOM_FORWARD_LAST_SKIP.set(nil)
    else
      AXIOM_FORWARD_LAST_ERROR.set(format_error(result.error))
      AXIOM_FORWARD_LAST_ERROR_AT.set(Time.now.utc.iso8601(3))
      warn "Axiom forward failed: #{AXIOM_FORWARD_LAST_ERROR.value}" if AppConfig.axiom[:debug]
    end
  end

  def format_error(error)
    return nil if error.nil?
    if error.respond_to?(:message)
      "#{error.class.name}: #{error.message}"
    else
      error.to_s
    end
  end

  def deployment_environment
    env = ENV["OTEL_DEPLOYMENT_ENV"].presence || Rails.env
    ci_run = ActiveModel::Type::Boolean.new.cast(ENV["CI"])
    return "ci" if ci_run || ENV["GITHUB_ACTIONS"] == "true"
    env
  end

  def ci_metadata
    ci_run = ActiveModel::Type::Boolean.new.cast(ENV["CI"])
    github_actions = ENV["GITHUB_ACTIONS"] == "true"
    metadata = {}

    if ci_run || github_actions
      metadata[:ci] = true
      metadata[:deployment_environment] = "ci"
    end

    if github_actions
      metadata[:ci_system] = "github_actions"
      metadata[:ci_pipeline_id] = ENV["GITHUB_RUN_ID"]
      metadata[:ci_pipeline_name] = ENV["GITHUB_WORKFLOW"]
      metadata[:ci_pipeline_number] = ENV["GITHUB_RUN_NUMBER"]
      metadata[:ci_job_name] = ENV["GITHUB_JOB"]
      metadata[:ci_repo] = ENV["GITHUB_REPOSITORY"]
      metadata[:ci_ref] = ENV["GITHUB_REF"]
      metadata[:ci_sha] = ENV["GITHUB_SHA"]
      metadata[:ci_actor] = ENV["GITHUB_ACTOR"]
      metadata[:ci_run_attempt] = ENV["GITHUB_RUN_ATTEMPT"]
      metadata[:ci_run_url] = if ENV["GITHUB_SERVER_URL"].present? && ENV["GITHUB_REPOSITORY"].present? && ENV["GITHUB_RUN_ID"].present?
        "#{ENV["GITHUB_SERVER_URL"]}/#{ENV["GITHUB_REPOSITORY"]}/actions/runs/#{ENV["GITHUB_RUN_ID"]}"
      end
    end

    metadata.compact
  end
end

Rails.application.configure do
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = proc do |severity, time, _progname, msg|
    payload = case msg
    when String then { message: msg }
    when Hash then msg
    else
      { message: msg.inspect }
    end

    skip_forward = payload.delete(StructuredLogger::AXIOM_FORWARD_SKIP_KEY) if payload.is_a?(Hash)

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
      app_version: AppConfig.app_version,
      user_id: Current.user_id,
      ip: Current.ip,
      ua: Current.user_agent,
      user_agent: Current.user_agent,
      path: Current.path,
      method: Current.method,
      trace_id: trace_id,
      span_id: span_id,
      _time: time.utc.iso8601(3)
    }

    enriched = base.merge(payload)
    # Plain Rails logs now stay on STDOUT; StructuredLogger handles Axiom forwarding explicitly.
    enriched.to_json + "\n"
  end

  config.logger = ActiveSupport::TaggedLogging.new(logger)
  config.log_tags = [ :request_id ]
end
