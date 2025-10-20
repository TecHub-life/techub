namespace :motifs do
  desc "Generate system motif artwork (archetypes + spirit animals) into public/library. Usage: rake motifs:generate[theme,ensure_only]"
  task :generate, [ :theme, :ensure_only ] => :environment do |_, args|
    theme = (args[:theme] || ENV["THEME"] || "core").to_s
    ensure_only = (args[:ensure_only] || ENV["ENSURE_ONLY"]).to_s.downcase.in?([ "1", "true", "yes" ]) || false

    puts "Generating motifs for theme=#{theme} ensure_only=#{ensure_only}..."
    res = Motifs::GenerateLibraryService.call(theme: theme, ensure_only: ensure_only)
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

  desc "Ensure motifs exist for theme (generate missing only). Usage: rake motifs:ensure[theme]"
  task :ensure, [ :theme ] => :environment do |_, args|
    theme = (args[:theme] || ENV["THEME"] || "core").to_s
    res = Motifs::GenerateLibraryService.call(theme: theme, ensure_only: true)
    if res.success?
      missing = (res.value[:archetypes] + res.value[:spirit_animals]).select { |r| r[:status] != "present" }
      if missing.empty?
        puts "All motif assets present for theme=#{theme}."
      else
        puts "Generated missing assets (#{missing.size})."
      end
    else
      warn "Motifs ensure failed: #{res.error.message}"
      exit 1
    end
  end
end
