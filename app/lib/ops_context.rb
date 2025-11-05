module OpsContext
  module_function

  def build(overrides = {})
    now = overrides[:at] || Time.current
    {
      ts_local: format_time(now, "Australia/Melbourne", "Australia/Melbourne"),
      ts_utc: format_time(now, "UTC", "UTC"),
      app: AppConfig.app[:name],
      environment: AppConfig.environment,
      service: overrides[:service].presence || AppConfig.app[:name],
      component: overrides[:component].presence || default_component,
      precedence: overrides[:precedence].presence || "ROUTINE",
      event: overrides[:event].presence || "unspecified",
      actor: overrides[:actor] || default_actor,
      details: overrides[:details]
    }.compact
  end

  def default_actor
    { human: "system", role: "MIDSHIPMAN" }
  end

  def default_component
    ENV["OPS_COMPONENT"].presence || (Current.job_id.present? ? "worker" : "web")
  rescue NameError
    "app"
  end

  def format_time(time, tz, label)
    time.in_time_zone(tz).strftime("%Y/%m/%d %H:%M (#{label})")
  end
  private_class_method :format_time
end
