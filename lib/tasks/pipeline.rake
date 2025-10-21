require "json"

namespace :profiles do
  desc "Run full pipeline via service (AI OFF by default)"
  task :pipeline, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host] || ENV["APP_HOST"]
    result = Profiles::GeneratePipelineService.call(login: login, host: host)
    if result.success?
      puts "✓ Pipeline completed for #{login}"
      puts "  - Card ID: #{result.value[:card_id]}"
      shots = (result.value[:screenshots] || {})
      shots.each { |variant, shot| puts "  - #{variant}: #{shot[:output_path]}" }
    else
      warn "Pipeline failed for #{login}: #{result.error.message}"
      if result.respond_to?(:metadata) && result.metadata.present?
        warn "Metadata: #{result.metadata.inspect}"
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
