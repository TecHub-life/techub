require "json"
require "fileutils"

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
