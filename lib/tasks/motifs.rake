namespace :motifs do
  desc "Generate system motif images+lore into public/library. Usage: rake motifs:generate[theme,ensure_only,lore_only,images_only,only,limit]"
  task :generate, [ :theme, :ensure_only, :lore_only, :images_only, :only, :limit ] => :environment do |_, args|
    theme = (args[:theme] || ENV["THEME"] || "core").to_s
    ensure_only = (args[:ensure_only] || ENV["ENSURE_ONLY"]).to_s.downcase.in?([ "1", "true", "yes" ]) || false
    lore_only = (args[:lore_only] || ENV["LORE_ONLY"]).to_s.downcase.in?([ "1", "true", "yes" ]) || false
    images_only = (args[:images_only] || ENV["IMAGES_ONLY"]).to_s.downcase.in?([ "1", "true", "yes" ]) || false
    only = args[:only] || ENV["ONLY"]
    limit = (args[:limit] || ENV["LIMIT"]).to_i if (args[:limit] || ENV["LIMIT"]).present?

    puts "Generating motifs for theme=#{theme} ensure_only=#{ensure_only} lore_only=#{lore_only} images_only=#{images_only} only=#{only} limit=#{limit}..."
    res = Motifs::GenerateLibraryService.call(theme: theme, ensure_only: ensure_only, lore_only: lore_only, images_only: images_only, only: only, limit: limit)
    if res.success?
      puts "Archetypes:"
      res.value[:archetypes].each { |r| puts "  - #{r[:slug]} [#{r[:aspect_ratio]}]: #{r[:status]} (#{r[:path]})" }
      puts "Spirit Animals:"
      res.value[:spirit_animals].each { |r| puts "  - #{r[:slug]} [#{r[:aspect_ratio]}]: #{r[:status]} (#{r[:path]})" }
    else
      warn "Motifs generation failed: #{res.error.message}"
      exit 1
    end
  end

  desc "Ensure motifs (images+lore) exist for theme (generate missing only). Usage: rake motifs:ensure[theme]"
  task :ensure, [ :theme ] => :environment do |_, args|
    theme = (args[:theme] || ENV["THEME"] || "core").to_s
    res = Motifs::GenerateLibraryService.call(theme: theme, ensure_only: true)
    if res.success?
      missing = (res.value[:archetypes] + res.value[:spirit_animals]).select { |r| r[:status] != "present" }
      if missing.empty?
        puts "All motif assets present for theme=#{theme}."
      else
        puts "Generated/ensured items (#{missing.size})."
      end
    else
      warn "Motifs ensure failed: #{res.error.message}"
      exit 1
    end
  end
end
