namespace :ops do
  desc "Smoke test Axiom: emit a StructuredLogger event"
  task :axiom_smoke, [ :message ] => :environment do |_, args|
    msg = args[:message].presence || "hello_world"
    if defined?(StructuredLogger)
      StructuredLogger.info(message: "axiom_smoke", sample: msg, invoked_by: ENV["USER"])
      puts "✓ Emitted axiom_smoke log: #{msg}"
      puts "If AXIOM_TOKEN and AXIOM_DATASET are set, this should appear in Axiom."
    else
      warn "StructuredLogger not defined"
      exit 1
    end
  end
end

namespace :ops do
  desc "Send a smoke test email (to=, message=)"
  task :send_test_email, [ :to, :message ] => :environment do |_t, args|
    to = args[:to]
    message = args[:message]
    abort "to is required" if to.to_s.strip.empty?
    SystemMailer.with(to: to, message: message).smoke_test.deliver_later
    puts "Queued smoke test email to #{to}"
  end

  desc "Re-run pipeline for specific logins without AI (comma-separated LOGINS)"
  task :bulk_retry, [ :logins ] => :environment do |_t, args|
    logins = (args[:logins] || "").split(",").map { |s| s.strip.downcase }.reject(&:empty?)
    abort "Provide LOGINS=login1,login2" if logins.empty?
    logins.each do |login|
      Profiles::GeneratePipelineJob.perform_later(login, ai: false)
    end
    puts "Queued Screenshots-Only re-run for #{logins.size} profile(s)"
  end

  desc "Re-run pipeline for specific logins with AI (comma-separated LOGINS)"
  task :bulk_retry_ai, [ :logins ] => :environment do |_t, args|
    logins = (args[:logins] || "").split(",").map { |s| s.strip.downcase }.reject(&:empty?)
    abort "Provide LOGINS=login1,login2" if logins.empty?
    now = Time.current
    Profile.where(login: logins).find_each do |p|
      Profiles::GeneratePipelineJob.perform_later(p.login, ai: true)
      p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: now)
    end
    puts "Queued Full (AI) re-run for #{logins.size} profile(s)"
  end

  desc "Re-run pipeline for ALL profiles without AI"
  task bulk_retry_all: :environment do
    count = 0
    Profile.find_each do |p|
      Profiles::GeneratePipelineJob.perform_later(p.login, ai: false)
      p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      count += 1
    end
    puts "Queued Screenshots-Only re-run for all (#{count}) profiles"
  end

  desc "Re-run pipeline for ALL profiles with AI"
  task bulk_retry_ai_all: :environment do
    count = 0
    now = Time.current
    Profile.find_each do |p|
      Profiles::GeneratePipelineJob.perform_later(p.login, ai: true)
      p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: now)
      count += 1
    end
    puts "Queued Full (AI) re-run for all (#{count}) profiles"
  end

  desc "Retry one profile without AI (LOGIN)"
  task :retry, [ :login ] => :environment do |_t, args|
    login = args[:login].to_s.downcase
    abort "Provide LOGIN=username" if login.empty?
    Profiles::GeneratePipelineJob.perform_later(login, ai: false)
    Profile.where(login: login).update_all(last_pipeline_status: "queued", last_pipeline_error: nil)
    puts "Re-run queued for @#{login} — Screenshots-Only"
  end

  desc "Retry one profile with AI (LOGIN)"
  task :retry_ai, [ :login ] => :environment do |_t, args|
    login = args[:login].to_s.downcase
    abort "Provide LOGIN=username" if login.empty?
    Profiles::GeneratePipelineJob.perform_later(login, ai: true)
    Profile.where(login: login).update_all(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: Time.current)
    puts "Full (AI) re-run queued for @#{login}"
  end

  desc "Delete a profile (LOGIN)"
  task :delete_profile, [ :login ] => :environment do |_t, args|
    login = args[:login].to_s.downcase
    abort "Provide LOGIN=username" if login.empty?
    profile = Profile.for_login(login).first
    abort "Profile not found" unless profile
    begin
      profile.destroy!
      puts "Deleted profile @#{login}"
    rescue ActiveRecord::InvalidForeignKey => e
      abort "Could not delete: #{e.message}"
    end
  end
end

namespace :social do
  desc "Generate social assets for specific logins (comma-separated LOGINS); UPLOAD=1 to upload"
  task :generate, [ :logins ] => :environment do |_t, args|
    logins = (args[:logins] || "").split(",").map { |s| s.strip.downcase }.reject(&:empty?)
    abort "Provide LOGINS=login1,login2" if logins.empty?
    upload = %w[1 true yes].include?(ENV["UPLOAD"].to_s.downcase)
    logins.each do |login|
      res = Profiles::GenerateSocialAssetsService.call(login: login, upload: upload)
      if res.success?
        puts "Generated social assets for @#{login}: #{res.value[:produced].map { |h| h[:kind] }.join(', ')}"
      else
        warn "Failed to generate for @#{login}: #{res.error&.message}"
      end
    end
  end

  desc "Generate social assets for ALL profiles; UPLOAD=1 to upload"
  task generate_all: :environment do
    upload = %w[1 true yes].include?(ENV["UPLOAD"].to_s.downcase)
    count = 0
    Profile.find_each do |p|
      res = Profiles::GenerateSocialAssetsService.call(login: p.login, upload: upload)
      if res.success?
        count += 1
      else
        warn "Failed for @#{p.login}: #{res.error&.message}"
      end
    end
    puts "Generated social assets for #{count} profile(s)"
  end
end
