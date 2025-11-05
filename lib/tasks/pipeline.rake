require "json"
require "fileutils"

namespace :pipeline do
  desc "Run the full pipeline locally and export artifacts. Usage: rake 'pipeline:run[login,host]'"
  task :run, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host].presence || ENV["PIPELINE_HOST"].presence || default_pipeline_host

    force = pipeline_truthy_env("PIPELINE_FORCE", default: false)
    save_artifacts = pipeline_truthy_env("PIPELINE_SAVE", default: true)

    ai_mode_env = ENV["PIPELINE_AI_MODE"].presence
    ai_mode = if force
      "real"
    else
      ai_mode_env.presence || "mock"
    end

    screenshots_mode = ENV["PIPELINE_SCREENSHOTS_MODE"].presence || ENV["PIPELINE_SCREENSHOTS"].presence

    overrides = {}
    overrides[:ai_mode] = ai_mode if ai_mode.present?
    overrides[:screenshots_mode] = screenshots_mode if screenshots_mode.present?

    puts "Running pipeline for @#{login} (host=#{host}, ai_mode=#{overrides[:ai_mode] || 'default'})..."
    result = Profiles::GeneratePipelineService.call(login: login, host: host, overrides: overrides)

    output_dir = pipeline_run_output_dir(login)
    if save_artifacts
      Profiles::Pipeline::SnapshotWriter.call(result: result, output_dir: output_dir, copy_files: true)
      puts "Artifacts saved to #{output_dir}"
    else
      puts "Artifacts not saved (PIPELINE_SAVE disabled). Intended path: #{output_dir}"
    end

    print_pipeline_summary(result, output_dir)
    exit 1 if result.failure?
  end
end

namespace :profiles do
  desc "Run full pipeline via service (AI OFF by default)"
  task :pipeline, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host] || ENV["APP_HOST"]
    result = Profiles::GeneratePipelineService.call(login: login, host: host)
    if result.success?
      puts "✓ Pipeline completed for #{login}"
      puts "  - Card ID: #{result.value[:card_id]}"
      shots = result.value[:screenshots] || {}
      shots.each do |variant, shot|
        puts "  - #{variant}: #{shot[:local_path]} (public: #{shot[:public_url] || "n/a"})"
      end
      if result.value[:optimizations].present?
        puts "\nOptimization:"
        result.value[:optimizations].each do |variant, metrics|
          puts "  - #{variant}: #{metrics[:size_before]} -> #{metrics[:size_after]} bytes (changed=#{metrics[:changed]})"
        end
      end
      if result.metadata[:trace].present?
        puts "\nTrace:"
        puts JSON.pretty_generate(result.metadata[:trace])
      end
    else
      warn "Pipeline failed for #{login}: #{result.error.message}"
      if result.respond_to?(:metadata) && result.metadata.present?
        warn "Metadata: #{result.metadata.inspect}"
        if result.metadata[:trace].present?
          warn "\nTrace:"
          warn JSON.pretty_generate(result.metadata[:trace])
        end
      end
      exit 1
    end
  end

  desc "Enqueue background pipeline job for a login"
  task :pipeline_enqueue, [ :login ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    Profiles::GeneratePipelineJob.perform_later(login)
    puts "Enqueued pipeline job for #{login}"
  end

  desc "Remove obsolete generated images for a login (old provider suffixes, duplicates)"
  task :cleanup_generated, [ :login ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    dir = Rails.root.join("public", "generated", login)
    patterns = [
      "avatar-*-ai_studio.*",
      "avatar-*-vertex.*",
      "og.png",
      "card.png",
      "simple.png"
    ]
    removed = []
    patterns.each do |glob|
      Dir[dir.join(glob).to_s].each do |path|
        begin
          File.delete(path)
          removed << File.basename(path)
        rescue StandardError
        end
      end
    end
    puts removed.any? ? "Removed: #{removed.join(', ')}" : "No obsolete files found for @#{login}"
  end
end

namespace :profiles do
  namespace :verify do
    desc "Run each pipeline stage, capturing before/after snapshots and artifacts"
    task :stages, [ :login, :output_dir, :host ] => :environment do |_, args|
      login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
      host = args[:host].presence || ENV["APP_HOST"].presence || default_pipeline_host
      output_dir = args[:output_dir]

      puts "Running stage verification for @#{login} (host=#{host})..."
      result = Profiles::Pipeline::Verifier.call(login: login, host: host, output_dir: output_dir)
      if result.success?
        puts "✓ Stage verification completed. Artifacts: #{result.value[:output_dir]}"
      else
        warn "Stage verification failed for @#{login}: #{result.error.message}"
        warn "Artifacts: #{(result.metadata || {})[:output_dir]}" if result.metadata&.key?(:output_dir)
        exit 1
      end
    end

    desc "Run full pipeline and save JSON + captures"
    task :pipeline, [ :login, :output_dir, :host ] => :environment do |_, args|
      login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
      host = args[:host].presence || ENV["APP_HOST"].presence || default_pipeline_host
      output_path = Pathname.new(args[:output_dir].presence || default_pipeline_output_dir(login))
      FileUtils.mkdir_p(output_path)

      puts "Running pipeline for @#{login} (host=#{host})..."
      result = Profiles::GeneratePipelineService.call(login: login, host: host)
      payload = {
        success: result.success?,
        value: result.value,
        metadata: result.metadata,
        error: result.error&.message,
        generated_at: Time.current.utc
      }
      File.write(output_path.join("pipeline_result.json"), JSON.pretty_generate(payload))
      copy_pipeline_captures(result.value, output_path.join("captures"))

      if result.success?
        puts "✓ Pipeline completed. Artifacts: #{output_path}"
      else
        warn "Pipeline failed for @#{login}: #{result.error.message}"
        warn "Artifacts: #{output_path}"
        exit 1
      end
    end
  end
end

namespace :profiles do
  desc "Doctor: run readiness checks for a login. Usage: rake 'profiles:doctor[login,host,email,variants]'"
  task :doctor, [ :login, :host, :email, :variants ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host].presence || ENV["APP_HOST"].presence
    email = args[:email].presence || ENV["EMAIL"].presence
    variants = (args[:variants].presence || ENV["VARIANTS"].presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS.join(",")).to_s.split(",").map(&:strip)

    result = Profiles::PipelineDoctorService.call(login: login, host: host, email: email, variants: variants)
    if result.success?
      puts JSON.pretty_generate(result.value)
    else
      warn "Doctor failed for @#{login}: #{result.error.message}"
      warn JSON.pretty_generate(result.metadata) if result.respond_to?(:metadata) && result.metadata
      exit 1
    end
  end
end

def default_pipeline_host
  Profiles::GeneratePipelineService::FALLBACK_HOSTS.fetch(Rails.env, "http://127.0.0.1:3000")
end

def default_pipeline_output_dir(login)
  timestamp = Time.current.utc.strftime("%Y%m%d%H%M%S")
  Rails.root.join("tmp", "pipeline_runs", "#{login}-#{timestamp}")
end

def copy_pipeline_captures(value, destination)
  return unless value.is_a?(Hash) && value[:screenshots].present?

  FileUtils.mkdir_p(destination)
  value[:screenshots].each do |variant, data|
    next unless data[:local_path] && File.exist?(data[:local_path])

    FileUtils.cp(data[:local_path], File.join(destination, "#{variant}#{File.extname(data[:local_path])}"))
  rescue StandardError
    # Ignore copy errors; paths remain available in JSON.
  end
end

def pipeline_truthy_env(key, default:)
  raw = ENV[key]
  return default if raw.nil?

  %w[1 true yes on].include?(raw.to_s.strip.downcase)
end

def pipeline_run_output_dir(login)
  safe_login = login.to_s.downcase
  timestamp = Time.current.utc.strftime("%Y%m%d%H%M%S")
  Rails.root.join("tmp", "pipeline_runs", "#{timestamp}-#{safe_login}")
end

def print_pipeline_summary(result, output_dir)
  status = result.respond_to?(:status) ? result.status : (result.success? ? :ok : :failed)
  metadata = result.respond_to?(:metadata) ? result.metadata || {} : {}

  puts "Pipeline status: #{status}"
  run_id = fetch_hash_value(metadata, :run_id)
  puts "Run ID: #{run_id}" if run_id.present?
  duration = fetch_hash_value(metadata, :duration_ms)
  puts "Duration: #{duration}ms" if duration

  if result.success?
    value = result.value
    if value.is_a?(Hash)
      puts "Card ID: #{value[:card_id]}" if value[:card_id]
      shots = fetch_hash_value(value, :screenshots)
      puts "Screenshots: #{shots.keys.join(', ')}" if shots.is_a?(Hash) && shots.any?
    end
  else
    error = result.error
    puts "Error: #{error.message}" if error.respond_to?(:message)
  end

  degraded = fetch_hash_value(metadata, :degraded_steps)
  if degraded.present?
    puts "Degraded stages:"
    Array(degraded).each do |entry|
      stage = fetch_hash_value(entry, :stage)
      info = fetch_hash_value(entry, :metadata)
      reason = fetch_hash_value(info, :reason) || fetch_hash_value(info, :message) || fetch_hash_value(info, :upstream_error)
      puts "  - #{stage}: #{reason || 'degraded'}"
    end
  end

  stages = fetch_hash_value(metadata, :stage_metadata)
  if stages.present?
    puts "Stage breakdown:"
    Profiles::GeneratePipelineService::STAGES.each do |stage|
      data = stage_metadata_lookup(stages, stage.id)
      next unless data

      stage_status = fetch_hash_value(data, :status) || (fetch_hash_value(data, :degraded) ? :degraded : :ok)
      stage_duration = fetch_hash_value(data, :duration_ms)
      stage_error = fetch_hash_value(data, :error)
      note = stage_note_for(data)

      line = "  - #{stage.label}: #{stage_status}"
      line += " (#{stage_duration}ms)" if stage_duration
      line += " - #{note}" if note.present?
      line += " (error: #{stage_error})" if stage_error.present?
      puts line
    end
  end

  if output_dir && File.directory?(output_dir)
    puts "Snapshot directory: #{output_dir}"
  end
end

def stage_metadata_lookup(stages, stage_id)
  fetch_hash_value(stages, stage_id)
end

def stage_note_for(data)
  meta = fetch_hash_value(data, :metadata)
  return unless meta.is_a?(Hash)

  notes = []
  notes << fetch_hash_value(meta, :reason)
  notes << fetch_hash_value(meta, :message)
  notes << fetch_hash_value(meta, :upstream_error)
  notes << "heuristic" if fetch_hash_value(meta, :heuristic)
  notes << "mock" if fetch_hash_value(meta, :mock)
  notes.compact!
  return nil if notes.empty?

  notes.uniq.join(" / ")
end

def fetch_hash_value(obj, key)
  return nil unless obj.is_a?(Hash)

  obj[key] || obj[key.to_s] || obj[key.to_sym]
end
