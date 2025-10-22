namespace :axiom do
  desc "Doctor: verify Axiom config and send a direct test event"
  task doctor: :environment do
    token = (Rails.application.credentials.dig(:axiom, :token) rescue nil) || ENV["AXIOM_TOKEN"]
    dataset = (Rails.application.credentials.dig(:axiom, :dataset) rescue nil) || ENV["AXIOM_DATASET"]
    metrics_dataset = (Rails.application.credentials.dig(:axiom, :metrics_dataset) rescue nil) || ENV["AXIOM_METRICS_DATASET"]
    enabled = !!(ENV["AXIOM_ENABLED"] == "1" || Rails.env.production?)

    puts "Axiom doctor"
    puts "  env: #{Rails.env}"
    puts "  token_present: #{token.to_s.strip != ''}"
    puts "  dataset: #{dataset || '(nil)'}"
    puts "  metrics_dataset: #{metrics_dataset || '(nil)'}"
    puts "  forwarding_enabled: #{enabled} (prod or AXIOM_ENABLED=1)"

    if token.to_s.strip.empty? || dataset.to_s.strip.empty?
      puts "Missing token or dataset. Configure credentials or env vars."
      exit(1)
    end

    require "faraday"
    conn = Faraday.new(url: "https://api.axiom.co") do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
    conn.headers["Authorization"] = "Bearer #{token}"
    payload = [ { ts: Time.now.utc.iso8601, level: "INFO", message: "axiom_doctor", env: Rails.env, app: "techub" } ]
    begin
      resp = conn.post("/v1/datasets/#{dataset}/ingest", payload)
      puts "POST /v1/datasets/#{dataset}/ingest => #{resp.status}"
      puts "OK — event sent"
    rescue Faraday::ResourceNotFound
      puts "Dataset '#{dataset}' not found."
      if ENV["AXIOM_ALLOW_DATASET_CREATE"] == "1"
        puts "Attempting to create it (AXIOM_ALLOW_DATASET_CREATE=1)..."
        begin
          create_resp = conn.post("/v2/datasets", { name: dataset, description: "techub logs" })
          puts "POST /v2/datasets => #{create_resp.status}"
          # Retry ingest once
          resp2 = conn.post("/v1/datasets/#{dataset}/ingest", payload)
          puts "POST /v1/datasets/#{dataset}/ingest => #{resp2.status}"
          puts "OK — event sent after creating dataset"
        rescue Faraday::Error => e
          warn "Create/ingest failed: #{e.class}: #{e.message}"
          exit(2)
        end
      else
        puts "Create the dataset in Axiom UI or set AXIOM_ALLOW_DATASET_CREATE=1 with a token that can create datasets."
        exit(4)
      end
    rescue Faraday::Error => e
      warn "HTTP error: #{e.class}: #{e.message}"
      exit(2)
    rescue StandardError => e
      warn "Error: #{e.class}: #{e.message}"
      exit(3)
    end

    # Optionally validate metrics dataset
    if metrics_dataset.to_s.strip != ""
      begin
        resp_m = conn.post("/v1/datasets/#{metrics_dataset}/ingest", [ { ts: Time.now.utc.iso8601, level: "INFO", message: "axiom_doctor_metrics", env: Rails.env, app: "techub" } ])
        puts "POST /v1/datasets/#{metrics_dataset}/ingest => #{resp_m.status}"
        puts "OK — metrics event sent"
      rescue Faraday::ResourceNotFound
        puts "Metrics dataset '#{metrics_dataset}' not found."
      rescue Faraday::Error => e
        warn "HTTP error (metrics): #{e.class}: #{e.message}"
      rescue StandardError => e
        warn "Error (metrics): #{e.class}: #{e.message}"
      end
    end
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
    dataset = (Rails.application.credentials.dig(:axiom, :metrics_dataset) rescue nil) || ENV["AXIOM_METRICS_DATASET"]
    abort "Set AXIOM_METRICS_DATASET or credentials[:axiom][:metrics_dataset]" if dataset.to_s.strip.empty?

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
      tracer.in_span("otel_smoke", attributes: { "smoke" => true, "env" => Rails.env, "service.name" => (ENV["OTEL_SERVICE_NAME"] || "techub") }) do
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
  desc "Self-test: log smoke (sync), OTEL span, and direct ingest"
  task self_test: :environment do
    dataset = (Rails.application.credentials.dig(:axiom, :dataset) rescue nil) || ENV["AXIOM_DATASET"]
    metrics_dataset = (Rails.application.credentials.dig(:axiom, :metrics_dataset) rescue nil) || ENV["AXIOM_METRICS_DATASET"]
    abort "Set credentials[:axiom][:dataset] or AXIOM_DATASET" if dataset.to_s.strip.empty?

    puts "Axiom self-test: dataset=#{dataset} metrics_dataset=#{metrics_dataset || '(nil)'}"

    # 1) StructuredLogger (forced, synchronous) — guaranteed delivery
    StructuredLogger.info({ message: "axiom_self_test_log", env: Rails.env, ts: Time.now.utc.iso8601 }, force_axiom: true)
    puts "  ✓ Log smoke sent"

    # 2) OTEL span
    Rake::Task["axiom:otel_smoke"].invoke

    # 3) Direct ingest via client
    event = { ts: Time.now.utc.iso8601, level: "INFO", kind: "axiom_self_test_direct", env: Rails.env }
    res = Axiom::IngestService.call(dataset: dataset, events: [ event ])
    if res.success?
      puts "  ✓ Direct ingest sent (status #{res.value})"
    else
      warn "  ✗ Direct ingest failed: #{res.error.message}"
      exit 3
    end

    # 4) Optional: metrics dataset ingest via client
    if metrics_dataset.to_s.strip != ""
      resm = Axiom::IngestService.call(dataset: metrics_dataset, events: [ event.merge(kind: "axiom_self_test_metrics") ])
      if resm.success?
        puts "  ✓ Metrics direct ingest sent (status #{resm.value})"
      else
        warn "  ✗ Metrics direct ingest failed: #{resm.error.message}"
      end
    end

    puts "Done. Check your dataset and traces UI."
  end
end
