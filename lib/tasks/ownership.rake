namespace :techub do
  namespace :ownership do
    desc "List all ownerships (profile -> user, owner?)"
    task list: :environment do
      rows = ProfileOwnership.includes(:profile, :user).order("profiles.login ASC, users.login ASC").references(:profile, :user)
      if rows.empty?
        puts "No ownerships found"
      else
        rows.each do |o|
          puts "@#{o.profile.login}  ->  @#{o.user.login}  [owner=#{o.is_owner ? 'yes' : 'no'}] (id=#{o.id})"
        end
      end
    end

    desc "List ownerships for a profile LOGIN"
    task :list_profile, [ :profile_login ] => :environment do |_t, args|
      abort "Usage: rake techub:ownership:list_profile[login]" if args[:profile_login].to_s.strip.empty?
      p = Profile.for_login(args[:profile_login]).first or abort "Profile not found"
      rows = ProfileOwnership.includes(:user).where(profile_id: p.id).order("users.login ASC").references(:user)
      puts "Profile @#{p.login}:"
      rows.each { |o| puts "  - @#{o.user.login} [owner=#{o.is_owner ? 'yes' : 'no'}] (id=#{o.id})" }
    end

    desc "List ownerships for a USER login"
    task :list_user, [ :user_login ] => :environment do |_t, args|
      abort "Usage: rake techub:ownership:list_user[user_login]" if args[:user_login].to_s.strip.empty?
      u = User.find_by(login: args[:user_login].to_s.downcase) or abort "User not found"
      rows = ProfileOwnership.includes(:profile).where(user_id: u.id).order("profiles.login ASC").references(:profile)
      puts "User @#{u.login}:"
      rows.each { |o| puts "  - @#{o.profile.login} [owner=#{o.is_owner ? 'yes' : 'no'}] (id=#{o.id})" }
    end

    desc "Claim ownership for USER_LOGIN on PROFILE_LOGIN (auto-promote rightful owner)"
    task :claim, [ :user_login, :profile_login ] => :environment do |_t, args|
      ulogin = args[:user_login].to_s.downcase
      plogin = args[:profile_login].to_s.downcase
      abort "Usage: rake techub:ownership:claim[user_login,profile_login]" if ulogin.empty? || plogin.empty?
      user = User.find_by(login: ulogin) or abort "User not found"
      profile = Profile.for_login(plogin).first or abort "Profile not found"
      result = Profiles::ClaimOwnershipService.call(user: user, profile: profile)
      if result.success?
        puts "Linked @#{user.login} to @#{profile.login}."
      else
        abort "Failed: #{result.error.message}"
      end
    end

    desc "Promote ownership by OWNERSHIP_ID to owner"
    task :promote, [ :ownership_id ] => :environment do |_t, args|
      id = args[:ownership_id].to_s
      abort "Usage: rake techub:ownership:promote[ownership_id]" if id.empty?
      o = ProfileOwnership.find_by(id: id) or abort "Ownership not found"
      ActiveRecord::Base.transaction do
        o.update!(is_owner: true)
        ProfileOwnership.where(profile_id: o.profile_id).where.not(id: o.id).delete_all
      end
      puts "Promoted ownership ##{o.id} (@#{o.user.login} -> @#{o.profile.login}) to owner"
    end

    desc "Demote ownership by OWNERSHIP_ID to manager"
    task :demote, [ :ownership_id ] => :environment do |_t, args|
      id = args[:ownership_id].to_s
      abort "Usage: rake techub:ownership:demote[ownership_id]" if id.empty?
      o = ProfileOwnership.find_by(id: id) or abort "Ownership not found"
      o.update!(is_owner: false)
      puts "Demoted ownership ##{o.id} (@#{o.user.login} -> @#{o.profile.login}) from owner"
    end

    desc "Remove ownership by OWNERSHIP_ID"
    task :remove, [ :ownership_id ] => :environment do |_t, args|
      id = args[:ownership_id].to_s
      abort "Usage: rake techub:ownership:remove[ownership_id]" if id.empty?
      o = ProfileOwnership.find_by(id: id) or abort "Ownership not found"
      o.destroy!
      puts "Removed ownership ##{id}"
    end

    desc "Set owner for PROFILE_LOGIN to USER_LOGIN (removes other links)"
    task :set_owner, [ :profile_login, :user_login ] => :environment do |_t, args|
      plogin = args[:profile_login].to_s.downcase
      ulogin = args[:user_login].to_s.downcase
      abort "Usage: rake techub:ownership:set_owner[profile_login,user_login]" if plogin.empty? || ulogin.empty?
      profile = Profile.for_login(plogin).first or abort "Profile not found"
      user = User.find_by(login: ulogin) or abort "User not found"
      # Force via same service + policy: claim (sets owner and removes others when login matches),
      # or promote via Ops-equivalent if logins differ.
      if user.login.downcase == profile.login.downcase
        result = Profiles::ClaimOwnershipService.call(user: user, profile: profile)
        abort "Failed: #{result.error.message}" if result.failure?
      else
        # Emulate Ops promote behavior
        ActiveRecord::Base.transaction do
          o = ProfileOwnership.find_or_create_by!(user_id: user.id, profile_id: profile.id)
          o.update!(is_owner: true)
          ProfileOwnership.where(profile_id: profile.id).where.not(id: o.id).delete_all
        end
      end
      puts "Set @#{user.login} as owner of @#{profile.login} (others removed)"
    end
  end
end
