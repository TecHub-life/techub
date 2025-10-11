namespace :profiles do
  desc "Synthesize and persist a ProfileCard for a login"
  task :card, [ :login ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    profile = Profile.find_by(login: login)
    unless profile
      puts "Fetching profile #{login}..."
      sync = Profiles::SyncFromGithub.call(login: login)
      if sync.failure?
        warn "Sync failed: #{sync.error.message}"
        exit 1
      end
      profile = sync.value
    end

    result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
    if result.success?
      card = result.value
      puts "Saved card for #{login}: ATK=#{card.attack} DEF=#{card.defense} SPD=#{card.speed}"
      puts "Tags: #{card.tags_array.join(', ')}"
    else
      warn "Card synthesis failed: #{result.error.message}"
      warn "Metadata: #{result.metadata.inspect}" if result.metadata
      exit 1
    end
  end
end
