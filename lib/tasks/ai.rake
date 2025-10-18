namespace :ai do
  PROVIDER_ORDER = %w[ai_studio vertex].freeze

  desc "Regenerate AI traits for a single profile (ADMIN)"
  task :traits, [ :login ] => :environment do |_, args|
    login = args[:login].to_s.downcase
    abort("Usage: rake ai:traits[login]") if login.blank?
    prof = Profile.for_login(login).first
    abort("Profile not found: #{login}") unless prof
    result = Profiles::SynthesizeAiProfileService.call(profile: prof)
    if result.success?
      puts "✓ AI traits generated for @#{login}"
    else
      warn "AI traits failed for @#{login}: #{result.error.message}"
      exit 1
    end
  end

  desc "Regenerate AI images for a single profile (ADMIN)"
  task :images, [ :login ] => :environment do |_, args|
    login = args[:login].to_s.downcase
    abort("Usage: rake ai:images[login]") if login.blank?
    result = Gemini::AvatarImageSuiteService.call(login: login, output_dir: Rails.root.join("public", "generated"))
    if result.success?
      puts "✓ AI images generated for @#{login}"
    else
      warn "AI images failed for @#{login}: #{result.error.message}"
      exit 1
    end
  end

  desc "Regenerate AI traits for many profiles (ADMIN). USAGE: rake ai:traits_bulk[logins] where logins=alice,bob"
  task :traits_bulk, [ :logins ] => :environment do |_, args|
    list = (args[:logins].to_s.split(",") || []).map(&:strip).reject(&:blank?)
    abort("Provide comma-separated logins") if list.empty?
    failures = []
    list.each do |login|
      prof = Profile.for_login(login).first
      unless prof
        warn "skip missing @#{login}"
        failures << login
        next
      end
      result = Profiles::SynthesizeAiProfileService.call(profile: prof)
      if result.success?
        puts "✓ @#{login}"
      else
        warn "× @#{login}: #{result.error.message}"
        failures << login
      end
    end
    exit 1 if failures.any?
  end

  namespace :traits do
    desc "Run structured traits generation against both providers for quick verification"
    task :verify, [ :login ] => :environment do |_, args|
      login = args[:login].to_s.downcase
      login = "loftwah" if login.blank?

      prof = Profile.for_login(login).first
      abort("Profile not found: #{login}") unless prof

      failures = []
      PROVIDER_ORDER.each do |provider|
        begin
          Gemini::Configuration.validate!(provider)
        rescue KeyError => e
          puts "Skipping #{provider}: #{e.message}"
          next
        end
        puts "\n=== Traits via #{provider} ==="
        result = Profiles::SynthesizeAiProfileService.call(profile: prof, provider: provider)
        if result.success?
          card = prof.profile_card
          puts "Provider #{provider} OK."
          if card
            puts "- Title: #{card.title}"
            puts "- Flavor: #{card.flavor_text}"
            puts "- Tags: #{Array(card.tags).join(', ')}"
          end
        else
          warn "Provider #{provider} FAILED: #{result.error.message}"
          warn "Metadata: #{result.metadata.inspect}" if result.metadata.present?
          failures << provider
        end
      end

      exit 1 if failures.any?
    end
  end
end
