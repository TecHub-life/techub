namespace :profiles do
  desc "Refresh profile data for a given GitHub login"
  task :refresh, [ :login ] => :environment do |_t, args|
    login = args[:login] || "loftwah"

    puts "Refreshing profile for #{login}..."

    profile = Profile.find_by(github_login: login)
    if profile
      puts "Deleting existing profile..."
      profile.destroy
    end

    puts "Fetching fresh data from GitHub..."
    result = Profiles::SyncFromGithub.call(login: login)

    if result.success?
      puts "Successfully refreshed profile for #{login}!"
      profile = result.value
      data = profile.data
      puts "Profile includes:"
      puts "  - Name: #{data['profile']['name']}"
      puts "  - Handle: @#{data['profile']['login']}"
      puts "  - Email: #{data['profile']['email'] || 'Not public'}"
      puts "  - Twitter: @#{data['profile']['twitter_username']}" if data["profile"]["twitter_username"]
      puts "  - Hireable: #{data['profile']['hireable'] ? 'Yes' : 'No'}"
      puts "  - Followers: #{data['profile']['followers']}"
      puts "  - Following: #{data['profile']['following']}"
      puts "  - Public Repos: #{data['profile']['public_repos']}"
      puts "  - Pinned Repos: #{data['pinned_repositories']&.length || 0}"
      puts "  - Active Repos: #{data['active_repositories']&.length || 0}"
      puts "  - Organizations: #{data['organizations']&.length || 0}"
      puts "  - Social Accounts: #{data['social_accounts']&.length || 0}"
      puts "  - README length: #{data['profile_readme']&.length || 0} characters"
    else
      puts "Error refreshing profile: #{result.error.message}"
      exit 1
    end
  end

  desc "Refresh all profiles"
  task refresh_all: :environment do
    Profile.find_each do |profile|
      puts "Refreshing #{profile.github_login}..."

      result = Profiles::SyncFromGithub.call(login: profile.github_login)

      if result.success?
        puts "  ✓ Success"
      else
        puts "  ✗ Failed: #{result.error.message}"
      end
    end

    puts "Done!"
  end
end
