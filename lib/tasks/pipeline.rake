require "json"

namespace :profiles do
  desc "Run full pipeline (sync → images → card → screenshots) for a login"
  task :pipeline, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host] || ENV["APP_HOST"]

    puts "Running pipeline for #{login}..."
    result = Profiles::GeneratePipelineService.call(login: login, host: host)
    if result.success?
      puts "✓ Pipeline completed"
      puts "  - Card ID: #{result.value[:card_id]}"
      if result.value[:screenshots]
        result.value[:screenshots].each do |variant, shot|
          puts "  - #{variant}: #{shot[:output_path]}"
        end
      end

      begin
        profile = Profile.for_login(login).first
        card = profile&.profile_card
        langs = profile&.top_languages(8)&.map(&:name) || []
        report = {
          generated_at: Time.now.utc.iso8601,
          login: login,
          profile: {
            name: profile&.display_name,
            followers: profile&.followers,
            location: profile&.location,
            created_at: profile&.github_created_at,
            top_languages: langs
          },
          card: card ? { id: card.id, attack: card.attack, defense: card.defense, speed: card.speed, tags: card.tags_array } : nil,
          screenshots: result.value[:screenshots],
          images: result.value[:images]
        }
        meta_dir = Rails.root.join("public", "generated", login, "meta")
        FileUtils.mkdir_p(meta_dir)
        File.write(meta_dir.join("pipeline-report.json"), JSON.pretty_generate(report))
        puts "Saved report: #{meta_dir.join('pipeline-report.json')}"
      rescue => e
        warn "Failed to write pipeline report: #{e.message}"
      end
    else
      warn "Pipeline failed: #{result.error.message}"
      warn "Metadata: #{result.metadata.inspect}" if result.metadata
      exit 1
    end
  end

  desc "Enqueue background pipeline job for a login"
  task :pipeline_enqueue, [ :login ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    Profiles::GeneratePipelineJob.perform_later(login)
    puts "Enqueued pipeline job for #{login}"
  end
end
