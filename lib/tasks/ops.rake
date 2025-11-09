require "json"

namespace :ops do
  desc "Smoke test Axiom: emit a StructuredLogger event"
  task :axiom_smoke, [ :message ] => :environment do |_, args|
    msg = args[:message].presence || "hello_world"
    if defined?(StructuredLogger)
      # Force Axiom forwarding regardless of env flag
      StructuredLogger.info({ message: "axiom_smoke", sample: msg, invoked_by: ENV["USER"], env: Rails.env }, force_axiom: true)
      puts "✓ Emitted axiom_smoke log (force_axiom): #{msg}"
      puts "If AXIOM_TOKEN and AXIOM_DATASET are set, this should appear in Axiom."
    else
      warn "StructuredLogger not defined"
      exit 1
    end
  end
end

namespace :ops do
  desc "Run integration doctor (SCOPE=gemini,axiom,github,spaces; PROVIDERS=ai_studio,vertex)"
  task :doctor, [ :scope ] => :environment do |_, args|
    scopes = args[:scope].to_s.split(",").map(&:strip)
    scopes = nil if scopes.all?(&:blank?)

    providers = ENV["PROVIDERS"].to_s.split(",").map(&:strip)
    providers = nil if providers.all?(&:blank?)

    result = Ops::IntegrationDoctorService.call(
      scopes: scopes,
      providers: providers
    )

    puts JSON.pretty_generate(result.metadata)
    exit(result.success? ? 0 : 1)
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

  desc "Re-run pipeline for specific logins (comma-separated LOGINS)"
  task :bulk_retry, [ :logins ] => :environment do |_t, args|
    logins = (args[:logins] || "").split(",").map { |s| s.strip.downcase }.reject(&:empty?)
    abort "Provide LOGINS=login1,login2" if logins.empty?
    logins.each do |login|
      Profiles::GeneratePipelineJob.perform_later(login, trigger_source: "ops:bulk_retry")
    end
    puts "Queued pipeline run for #{logins.size} profile(s)"
  end

  desc "Re-run pipeline for ALL profiles"
  task bulk_retry_all: :environment do
    count = 0
    Profile.find_each do |p|
      Profiles::GeneratePipelineJob.perform_later(p.login, trigger_source: "ops:bulk_retry_all")
      p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      count += 1
    end
    puts "Queued pipeline run for all (#{count}) profiles"
  end

  desc "Retry one profile (LOGIN)"
  task :retry, [ :login ] => :environment do |_t, args|
    login = args[:login].to_s.downcase
    abort "Provide LOGIN=username" if login.empty?
    Profiles::GeneratePipelineJob.perform_later(login, trigger_source: "ops:retry")
    Profile.where(login: login).update_all(last_pipeline_status: "queued", last_pipeline_error: nil)
    puts "Pipeline run queued for @#{login}"
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
      Screenshots::CaptureCardService::SOCIAL_VARIANTS.each do |kind|
        Screenshots::CaptureCardJob.perform_later(login: login, variant: kind)
      end
      puts "Enqueued social screenshots for @#{login}: #{Screenshots::CaptureCardService::SOCIAL_VARIANTS.join(', ')}"
    end
  end

  desc "Generate social assets for ALL profiles; UPLOAD=1 to upload"
  task generate_all: :environment do
    upload = %w[1 true yes].include?(ENV["UPLOAD"].to_s.downcase)
    count = 0
    Profile.find_each do |p|
      Screenshots::CaptureCardService::SOCIAL_VARIANTS.each do |kind|
        Screenshots::CaptureCardJob.perform_later(login: p.login, variant: kind)
      end
      count += 1
    end
    puts "Enqueued social screenshots for #{count} profile(s)"
  end
end
