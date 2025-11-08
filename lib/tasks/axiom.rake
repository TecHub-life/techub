namespace :axiom do
  desc "Doctor: verify Axiom config and send a direct test event"
  task doctor: :environment do
    cfg = AppConfig.axiom
    forwarding = AppConfig.axiom_forwarding

    puts "Axiom doctor"
    puts "  env: #{AppConfig.environment}"
    puts "  dataset: #{cfg[:dataset] || '(nil)'}"
    dataset_source =
      if ENV["AXIOM_DATASET"].present?
        "env[AXIOM_DATASET]"
      else
        "AppConfig default (#{AppConfig::DEFAULT_AXIOM_LOGS_DATASET})"
      end
    puts "  dataset_source: #{dataset_source}"
    puts "  metrics_dataset: #{cfg[:metrics_dataset] || '(nil)'}"
    metrics_source =
      if ENV["AXIOM_TRACES_DATASET"].present?
        "env[AXIOM_TRACES_DATASET]"
      elsif ENV["AXIOM_METRICS_DATASET"].present?
        "env[AXIOM_METRICS_DATASET]"
      else
        "AppConfig default (#{AppConfig::DEFAULT_AXIOM_TRACES_DATASET})"
      end
    puts "  metrics_source: #{metrics_source}"
    puts "  token_present: #{forwarding[:token_present]}"
    puts "  forwarding_allowed: #{forwarding[:allowed]} (reason=#{forwarding[:reason]})"
    puts "  base_url: #{cfg[:base_url]}"

    if cfg[:token].to_s.strip.empty? || cfg[:dataset].to_s.strip.empty?
      puts "Missing token or dataset. Configure credentials or env vars."
      exit(1)
    end

    require "faraday"
    conn = Faraday.new(url: cfg[:base_url] || "https://api.axiom.co") do |f|
      f.request :retry
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
    conn.headers["Authorization"] = "Bearer #{cfg[:token]}"
    payload = [ { ts: Time.now.utc.iso8601, level: "INFO", message: "axiom_doctor", env: Rails.env, app: AppConfig.app[:name] } ]
    begin
      resp = conn.post("/v1/datasets/#{cfg[:dataset]}/ingest") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end
      puts "POST /v1/datasets/#{cfg[:dataset]}/ingest => #{resp.status}"
      puts "OK — event sent"
    rescue Faraday::ResourceNotFound
      puts "Dataset '#{cfg[:dataset]}' not found. Create it in the Axiom UI and rerun."
      exit(4)
    rescue Faraday::Error => e
      warn "HTTP error: #{e.class}: #{e.message}"
      exit(2)
    rescue StandardError => e
      warn "Error: #{e.class}: #{e.message}"
      exit(3)
    end

    # Optionally validate metrics dataset
    if cfg[:metrics_dataset].to_s.strip != ""
      begin
        resp_m = conn.post("/v1/datasets/#{cfg[:metrics_dataset]}/ingest") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = [ { ts: Time.now.utc.iso8601, level: "INFO", message: "axiom_doctor_metrics", env: Rails.env, app: AppConfig.app[:name] } ].to_json
        end
        puts "POST /v1/datasets/#{cfg[:metrics_dataset]}/ingest => #{resp_m.status}"
        puts "OK — metrics event sent"
      rescue Faraday::ResourceNotFound
        puts "Metrics dataset '#{cfg[:metrics_dataset]}' not found."
      rescue Faraday::Error => e
        warn "HTTP error (metrics): #{e.class}: #{e.message}"
      rescue StandardError => e
        warn "Error (metrics): #{e.class}: #{e.message}"
      end
    end
  end

  desc "Runtime doctor: verify StructuredLogger forwarding and queue health"
  task runtime_doctor: :environment do
    require "securerandom"

    cfg = AppConfig.axiom
    forwarding = AppConfig.axiom_forwarding
    stats_before = StructuredLogger.forwarding_stats

    puts "Axiom runtime doctor"
    puts "  env: #{AppConfig.environment}"
    puts "  dataset: #{cfg[:dataset] || '(nil)'}"
    puts "  token_present: #{forwarding[:token_present]}"
    puts "  forwarding_allowed: #{forwarding[:allowed]} (reason=#{forwarding[:reason]})"
    puts "  queue_before: enqueued=#{stats_before[:enqueued]} delivered=#{stats_before[:delivered]} pending=#{stats_before[:pending]}"

    unless forwarding[:allowed]
      puts "Forwarding disabled, cannot verify runtime delivery."
      exit 10
    end

    doctor_id = SecureRandom.uuid
    StructuredLogger.info(
      { message: "axiom_runtime_doctor_forced", doctor_id: doctor_id, env: Rails.env, app: AppConfig.app[:name] },
      force_axiom: true,
      component: "ops",
      precedence: "IMMEDIATE",
      ops_details: { doctor: "axiom_runtime" }
    )

    forced_stats = StructuredLogger.forwarding_stats
    last_delivery = forced_stats[:last_delivery]
    if forced_stats[:last_error]
      warn "  ✗ Forced delivery failed: #{forced_stats[:last_error]}"
      exit 2
    end
    puts "  ✓ Forced delivery status=#{last_delivery&.dig(:status)} at=#{last_delivery&.dig(:at)} pending=#{forced_stats[:pending]}"

    StructuredLogger.info(
      { message: "axiom_runtime_doctor_async", doctor_id: doctor_id, env: Rails.env, app: AppConfig.app[:name] },
      component: "ops",
      precedence: "ROUTINE",
      ops_details: { doctor: "axiom_runtime" }
    )

    deadline = Time.now + 5
    loop do
      stats = StructuredLogger.forwarding_stats
      break if stats[:pending].zero? || Time.now > deadline
      sleep 0.1
    end

    final_stats = StructuredLogger.forwarding_stats
    if final_stats[:pending].positive?
      warn "  ✗ Queue did not drain within 5s (pending=#{final_stats[:pending]})"
      exit 3
    end

    if final_stats[:last_error]
      warn "  ✗ Async delivery error: #{final_stats[:last_error]}"
      exit 4
    end

    puts "  ✓ Async queue drained (pending=#{final_stats[:pending]})"
    puts "  queue_after: enqueued=#{final_stats[:enqueued]} delivered=#{final_stats[:delivered]}"
  end

  desc "Emit a StructuredLogger smoke (force Axiom)"
  task :smoke, [ :message ] => :environment do |_t, args|
    msg = args[:message].presence || "hello_world"
    StructuredLogger.info({ message: "axiom_smoke", sample: msg, env: Rails.env }, force_axiom: true)
    puts "Emitted StructuredLogger smoke (force_axiom=true): #{msg}"
  end

  desc "Send today's ProfileStat snapshots to a metrics dataset (AXIOM_METRICS_DATASET or credentials)"
  task :stats_snapshot, [ :date ] => :environment do |_t, args|
    date = (args[:date].presence && Date.parse(args[:date])) || Date.today
    cfg = AppConfig.axiom
    dataset = cfg[:metrics_dataset]
    abort "Set credentials[:axiom][:metrics_dataset] or AXIOM_METRICS_DATASET" if dataset.to_s.strip.empty?

    events = []
    ProfileStat.where(stat_date: date).includes(:profile).find_each do |s|
      events << {
        ts: Time.now.utc.iso8601,
        level: "INFO",
        kind: "profile_stats",
        login: s.profile.login,
        date: s.stat_date,
        followers: s.followers,
        following: s.following,
        public_repos: s.public_repos,
        total_stars: s.total_stars,
        total_forks: s.total_forks,
        repo_count: s.repo_count
      }
    end
    if events.empty?
      puts "No ProfileStat rows for #{date}"
      next
    end
    res = Axiom::IngestService.call(dataset: dataset, events: events)
    if res.success?
      puts "Sent #{events.size} events to #{dataset}"
    else
      warn "Ingest failed: #{res.error.message}"
      exit 2
    end
  end

  desc "Emit a simple OpenTelemetry span to verify OTLP export"
  task otel_smoke: :environment do
    begin
      require "opentelemetry/sdk"
      tracer = OpenTelemetry.tracer_provider.tracer("techub.smoke", "1.0")
      tracer.in_span("otel_smoke", attributes: { "smoke" => true, "env" => Rails.env, "service.name" => "techub" }) do
        sleep 0.01
      end
      puts "OTEL smoke span emitted — check your Axiom traces UI."
    rescue LoadError
      warn "OpenTelemetry gems not installed. Run bundle install."
      exit 2
    rescue StandardError => e
      warn "OTEL smoke failed: #{e.class}: #{e.message}"
      exit 3
    end
  end
end

namespace :axiom do
  desc "Emit a simple OpenTelemetry metrics data point to verify OTLP metrics export"
  task otel_metrics_smoke: :environment do
    begin
      require "opentelemetry/sdk"
      unless OpenTelemetry.respond_to?(:meter_provider)
        warn "OTEL metrics smoke skipped: current opentelemetry gem does not expose meter APIs. Upgrade opentelemetry-api/sdk >= 1.2 to test metrics."
        exit 0
      end
      meter = OpenTelemetry.meter_provider.meter("techub.metrics", "1.0")
      counter = meter.create_counter("otel_smoke_metric_total", unit: "1", description: "OTEL metrics smoke counter")
      counter.add(1, attributes: { env: Rails.env })
      # Give the PeriodicExportingMetricReader a moment to export on its interval (if short)
      sleep 2
      puts "OTEL metrics smoke emitted — check your Axiom metrics UI for otel_smoke_metric_total."
    rescue LoadError
      warn "OpenTelemetry gems not installed. Run bundle install."
      exit 2
    rescue StandardError => e
      warn "OTEL metrics smoke failed: #{e.class}: #{e.message}"
      exit 3
    end
  end
  desc "Self-test: log smoke (sync), OTEL span, and direct ingest"
  task self_test: :environment do
    cfg = AppConfig.axiom
    dataset = cfg[:dataset]
    metrics_dataset = cfg[:metrics_dataset]
    abort "Set credentials[:axiom][:dataset] or AXIOM_DATASET" if dataset.to_s.strip.empty?

    puts "Axiom self-test: dataset=#{dataset} metrics_dataset=#{metrics_dataset || '(nil)'}"

    # 1) StructuredLogger (forced, synchronous) — guaranteed delivery
    StructuredLogger.info({ message: "axiom_self_test_log", env: Rails.env, ts: Time.now.utc.iso8601 }, force_axiom: true, component: "ops")
    puts "  ✓ Log smoke sent"

    # 2) OTEL span
    Rake::Task["axiom:otel_smoke"].invoke

    # 3) Direct ingest via client
    event = { ts: Time.now.utc.iso8601, level: "INFO", kind: "axiom_self_test_direct", env: Rails.env }
    res = Axiom::IngestService.call(dataset: dataset, events: [ event ])
    if res.success?
      puts "  ✓ Direct ingest sent (status #{res.value})"
    else
      warn "  ✗ Direct ingest failed: #{StructuredLogger.describe_error(res.error)}"
      exit 3
    end

    # 4) Optional: metrics dataset ingest via client
    if metrics_dataset.to_s.strip != ""
      resm = Axiom::IngestService.call(dataset: metrics_dataset, events: [ event.merge(kind: "axiom_self_test_metrics") ])
      if resm.success?
        puts "  ✓ Metrics direct ingest sent (status #{resm.value})"
      else
        warn "  ✗ Metrics direct ingest failed: #{StructuredLogger.describe_error(resm.error)}"
      end
    end

    puts "Done. Check your dataset and traces UI."
  end

  desc "Primary smoke: structured log + OTEL span + direct ingest (alias for axiom:self_test)"
  task smoke_all: :self_test
end
