# frozen_string_literal: true

require "socket"

Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next unless defined?(StructuredLogger)

  hostname = begin
    Socket.gethostname
  rescue StandardError
    nil
  end

  boot_payload = {
    message: "system_boot",
    env: Rails.env,
    app: AppConfig.app[:name],
    app_version: AppConfig.app_version,
    hostname: hostname,
    pid: Process.pid,
    ruby_version: RUBY_VERSION,
    rails_version: Rails.version,
    boot_time: Time.current.utc.iso8601
  }

  begin
    boot_payload[:upright_commit] = `git rev-parse --short HEAD`.strip if defined?(Rails.root) && Rails.root.join(".git").exist?
  rescue StandardError
  end

  begin
    forwarding = AppConfig.axiom_forwarding
    boot_payload[:axiom_forwarding_allowed] = forwarding[:allowed]
    boot_payload[:axiom_forwarding_reason] = forwarding[:reason]
    boot_payload[:axiom_token_present] = forwarding[:token_present]
    boot_payload[:axiom_dataset_present] = forwarding[:dataset_present]
  rescue StandardError => e
    boot_payload[:axiom_forwarding_error] = e.message
  end

  begin
    threads = Thread.list
    boot_payload[:thread_count] = threads.size
  rescue StandardError
  end

  begin
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      boot_payload[:db_ready] = conn.active?
      if conn.respond_to?(:migration_context)
        boot_payload[:db_migrations_pending] = conn.migration_context.needs_migration?
      else
        boot_payload[:db_migrations_pending] = ActiveRecord::Migrator.needs_migration?
      end
    end
  rescue StandardError => e
    boot_payload[:db_error] = e.message
  end

  begin
    require "socket"
    ipv4s = Socket.ip_address_list.select(&:ipv4?).map(&:ip_address)
    boot_payload[:ip_addresses] = ipv4s
  rescue StandardError
  end

  begin
    boot_payload[:feature_flags] = {
      ai_text: FeatureFlags.enabled?(:ai_text),
      require_profile_eligibility: FeatureFlags.enabled?(:require_profile_eligibility)
    }
  rescue NameError
  rescue StandardError => e
    boot_payload[:feature_flag_error] = e.message
  end

  begin
    if defined?(SolidQueue::Job)
      boot_payload[:queue_counts] = {
        total_jobs: SolidQueue::Job.count,
        ready_jobs: SolidQueue::Job.ready.count,
        future_jobs: SolidQueue::Job.scheduled.count
      }
    end
  rescue StandardError => e
    boot_payload[:queue_error] = e.message
  end

  begin
    queue_stats = StructuredLogger.forwarding_stats
    boot_payload[:logger_queue_pending] = queue_stats[:pending]
    boot_payload[:logger_last_skip_reason] = queue_stats.dig(:last_skip, :reason)
  rescue StandardError
    # swallow optional diagnostics errors
  end

  StructuredLogger.info(
    boot_payload,
    component: "system",
    precedence: "IMMEDIATE",
    ops_details: boot_payload.slice(:axiom_forwarding_allowed, :axiom_forwarding_reason, :db_migrations_pending)
  )
end
