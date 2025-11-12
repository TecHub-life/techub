module UsersTasks
  module_function

  def truthy?(value)
    %w[1 true yes on y].include?(value.to_s.strip.downcase)
  end

  def boolean_env?(name, default: false)
    return default unless ENV.key?(name)

    truthy?(ENV[name])
  end

  def locate_user(identifier)
    ident = identifier.to_s.strip
    return if ident.empty?

    if ident.match?(/\A\d+\z/)
      by_id = User.find_by(id: ident.to_i)
      return by_id if by_id

      by_github = User.find_by(github_id: ident.to_i)
      return by_github if by_github
    end

    lowered = ident.downcase
    User.find_by(login: lowered) || User.find_by(email: lowered)
  end
end

namespace :users do
  desc "List recent users (FILTER=substring, LIMIT=25, MAX=200)."
  task list: :environment do
    filter_value = ENV["FILTER"].to_s.strip.downcase
    limit = (ENV["LIMIT"].presence || 25).to_i
    limit = 200 if limit > 200
    base_scope = User.left_outer_joins(:profile_ownerships)
                     .select("users.*, COUNT(profile_ownerships.id) AS ownerships_count")
                     .group("users.id")
                     .order(created_at: :desc)
    unless filter_value.empty?
      clauses = [
        "LOWER(users.login) LIKE :filter",
        "LOWER(COALESCE(users.email, '')) LIKE :filter"
      ]
      params = { filter: "%#{filter_value}%" }
      if filter_value.match?(/\A\d+\z/)
        clauses << "users.id = :exact_id"
        clauses << "CAST(users.github_id AS TEXT) = :exact_text"
        params[:exact_id] = filter_value.to_i
        params[:exact_text] = filter_value
      end
      base_scope = base_scope.where("(#{clauses.join(' OR ')})", params)
    end

    rows = base_scope.limit(limit)
    if rows.empty?
      puts "No users found."
      next
    end

    header = format("%-6s %-20s %-28s %-8s %-20s", "ID", "Login", "Email", "Profiles", "Created")
    puts header
    puts "-" * header.length
    rows.each do |user|
      ownerships = user.read_attribute(:ownerships_count).to_i
      created_at = user.created_at&.utc&.strftime("%Y-%m-%d %H:%M")
      puts format(
        "%-6d %-20s %-28s %-8d %-20s",
        user.id,
        user.login,
        (user.email.presence || "-"),
        ownerships,
        created_at
      )
    end
    puts "Displayed #{rows.size} user#{'s' if rows.size != 1}. Use LIMIT=N to adjust."
  end

  desc "Delete a user by login/email/id. Example: rake users:delete[octocat] CONFIRM=octocat"
  task :delete, [ :identifier ] => :environment do |_t, args|
    identifier = [ args[:identifier], ENV["IDENTIFIER"], ENV["LOGIN"], ENV["ID"] ]
                 .compact
                 .map { |value| value.to_s.strip }
                 .find { |value| value.present? }
    abort "Usage: rake users:delete[identifier] CONFIRM=<login or id>" unless identifier

    user = UsersTasks.locate_user(identifier)
    abort "User not found for #{identifier.inspect}" unless user

    confirm = ENV["CONFIRM"].to_s.strip
    force = UsersTasks.boolean_env?("FORCE")
    unless force || confirm.casecmp?(user.login) || confirm == user.id.to_s
      abort "Refusing to delete #{user.login}. Pass CONFIRM=#{user.login.inspect} (or CONFIRM=#{user.id}) or FORCE=1."
    end

    ownerships = user.profile_ownerships.count
    notifications = user.notification_deliveries.count
    user.destroy!
    puts "Deleted user ##{user.id} (@#{user.login}). Removed #{ownerships} ownership#{'s' if ownerships != 1} and #{notifications} notification#{'s' if notifications != 1}."
  rescue ActiveRecord::RecordNotDestroyed => e
    abort "Failed to delete user: #{e.record.errors.full_messages.to_sentence}"
  end

  desc "Remove users who never claimed a profile (APPLY=1 to delete, OLDER_THAN_DAYS=7)."
  task cleanup_orphans: :environment do
    older_than_days = (ENV["OLDER_THAN_DAYS"].presence || 7).to_i
    scope = User.left_outer_joins(:profile_ownerships).where(profile_ownerships: { id: nil })
    if older_than_days.positive?
      scope = scope.where("users.created_at <= ?", older_than_days.days.ago)
    end

    total = scope.count
    if total.zero?
      puts "No orphaned users detected."
      next
    end

    window_description =
      if older_than_days.positive?
        "created #{older_than_days}+ days ago"
      else
        "created at any time"
      end
    puts "Found #{total} orphaned user#{'s' if total != 1} (#{window_description})."

    preview = scope.order(created_at: :asc).limit(10)
    preview.each do |user|
      puts format("  #%<id>d @%<login>s — created %<created>s", id: user.id, login: user.login, created: user.created_at.strftime("%Y-%m-%d"))
    end
    remaining = total - preview.size
    puts "  ...and #{remaining} more" if remaining.positive?

    apply = UsersTasks.boolean_env?("APPLY") || UsersTasks.boolean_env?("FORCE")
    unless apply
      puts "Dry run. Set APPLY=1 (or FORCE=1) to delete the orphaned users above."
      next
    end

    scope.order(:id).find_each do |user|
      user.destroy!
      puts "Deleted user ##{user.id} (@#{user.login})"
    end
    puts "Removed #{total} orphaned user#{'s' if total != 1}."
  end
end
