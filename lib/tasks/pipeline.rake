require "json"

namespace :profiles do
  desc "Run full pipeline (sync → images → card → screenshots) for a login"
  task :pipeline, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    host = args[:host] || ENV["APP_HOST"]
    verbose = ENV["VERBOSE"].to_s.downcase.in?([ "1", "true", "yes" ]) || true

    meta_dir = Rails.root.join("public", "generated", login, "meta")
    FileUtils.mkdir_p(meta_dir)
    events_path = meta_dir.join("pipeline-events.jsonl")

    def log_event(io_path, stage:, message:, **data)
      payload = { ts: Time.now.utc.iso8601, stage: stage, message: message, **data }
      puts("[#{payload[:ts]}] #{stage}: #{message}")
      File.open(io_path, "a") { |f| f.puts(payload.to_json) }
    rescue => e
      warn "log_event failed: #{e.message}"
    end

    log_event(events_path, stage: "start", message: "pipeline start", login: login, host: host)

    # Step 1: Sync profile from GitHub
    log_event(events_path, stage: "sync", message: "sync_from_github:begin")
    sync = Profiles::SyncFromGithub.call(login: login)
    if sync.failure?
      log_event(events_path, stage: "sync", message: "sync_from_github:error", error: sync.error.message)
      warn "Pipeline failed during sync: #{sync.error.message}"
      exit 1
    end
    profile = sync.value
    profile_summary = {
      name: profile&.display_name,
      login: profile&.login,
      followers: profile&.followers,
      following: profile&.following,
      location: profile&.location,
      created_at: profile&.github_created_at,
      languages: profile&.top_languages(8)&.map(&:name),
      top_repositories: profile&.profile_repositories&.where(repository_type: "top")&.order(stargazers_count: :desc)&.limit(3)&.pluck(:name),
      organizations: profile&.profile_organizations&.limit(3)&.pluck(:login)
    }
    log_event(events_path, stage: "sync", message: "sync_from_github:ok", profile: profile_summary.compact)

    # Step 1.5: Eligibility gate (flagged)
    if FeatureFlags.enabled?(:require_profile_eligibility)
      log_event(events_path, stage: "eligibility", message: "evaluate:begin")
      begin
        # Reuse service's evaluation shape
        repositories = profile.profile_repositories.map do |r|
          { private: false, archived: false, pushed_at: r.github_updated_at, owner_login: (r.full_name&.split("/")&.first || profile.login) }
        end
        recent_activity = { total_events: profile.profile_activity&.total_events.to_i }
        pinned = profile.profile_repositories.where(repository_type: "pinned").map { |r| { name: r.name } }
        readme = profile.profile_readme&.content
        orgs = profile.profile_organizations.map { |o| { login: o.login } }
        payload = { login: profile.login, followers: profile.followers, following: profile.following, created_at: profile.github_created_at }
        elig = Eligibility::GithubProfileScoreService.call(
          profile: payload,
          repositories: repositories,
          recent_activity: recent_activity,
          pinned_repositories: pinned,
          profile_readme: readme,
          organizations: orgs
        ) rescue nil
        elig_value = elig&.respond_to?(:value) ? elig.value : nil
        if elig_value && !elig_value[:eligible]
          log_event(events_path, stage: "eligibility", message: "evaluate:fail", result: elig_value)
          warn "Pipeline halted: profile_not_eligible"
          File.write(meta_dir.join("pipeline-report.json"), JSON.pretty_generate({ generated_at: Time.now.utc.iso8601, login: login, error: "profile_not_eligible", eligibility: elig_value }))
          exit 1
        else
          log_event(events_path, stage: "eligibility", message: "evaluate:ok", result: elig_value)
        end
      rescue => e
        log_event(events_path, stage: "eligibility", message: "evaluate:error", error: e.message)
      end
    end

    # Step 2: Optional ingest/scrape when present
    submitted_full_names = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name).compact
    if submitted_full_names.any?
      log_event(events_path, stage: "ingest", message: "submitted_repos:begin", repos: submitted_full_names)
      begin
        Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: submitted_full_names)
        log_event(events_path, stage: "ingest", message: "submitted_repos:ok")
      rescue => e
        log_event(events_path, stage: "ingest", message: "submitted_repos:error", error: e.message)
      end
    end

    if profile.respond_to?(:submitted_scrape_url) && profile.submitted_scrape_url.present?
      log_event(events_path, stage: "scrape", message: "record:begin", url: profile.submitted_scrape_url)
      begin
        scraped_result = Profiles::RecordSubmittedScrapeService.call(profile: profile, url: profile.submitted_scrape_url)
        if scraped_result.success?
          log_event(events_path, stage: "scrape", message: "record:ok")
        else
          log_event(events_path, stage: "scrape", message: "record:fail", error: scraped_result.error.message)
        end
      rescue => e
        log_event(events_path, stage: "scrape", message: "record:error", error: e.message)
      end
    end

    # Step 3: Generate images (prompts + variants)
    log_event(events_path, stage: "images", message: "image_generation:begin")
    images = Gemini::AvatarImageSuiteService.call(
      login: login,
      provider: nil,
      filename_suffix: nil,
      output_dir: Rails.root.join("public", "generated")
    )
    if images.failure?
      log_event(events_path, stage: "images", message: "image_generation:error", error: images.error.message, metadata: images.metadata)
      warn "Pipeline failed during image generation: #{images.error.message}"
      exit 1
    end
    images_value = images.value
    log_event(events_path, stage: "images", message: "image_generation:ok", variants: images_value[:images]&.keys)

    # Attempt to load prompt artifacts
    prompts_glob = Dir[meta_dir.join("prompts-*.json").to_s]
    meta_glob = Dir[meta_dir.join("meta-*.json").to_s]
    prompt_artifacts = {}
    begin
      if prompts_glob.first && File.exist?(prompts_glob.first)
        prompt_artifacts[:prompts_file] = prompts_glob.first
        prompt_artifacts[:prompts] = JSON.parse(File.read(prompts_glob.first))
      end
      if meta_glob.first && File.exist?(meta_glob.first)
        prompt_artifacts[:provider_meta_file] = meta_glob.first
        prompt_artifacts[:provider_meta] = JSON.parse(File.read(meta_glob.first))
      end
    rescue => e
      log_event(events_path, stage: "images", message: "artifact_load:error", error: e.message)
    end
    if prompt_artifacts[:prompts_file]
      log_event(events_path, stage: "images", message: "artifact_load:ok", prompts_file: prompt_artifacts[:prompts_file])
      puts "Prompts saved to: #{prompt_artifacts[:prompts_file]}"
    end

    # Step 4: Synthesize card attributes
    log_event(events_path, stage: "card", message: "synthesize_card:begin")
    synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
    if synth.failure?
      log_event(events_path, stage: "card", message: "synthesize_card:error", error: synth.error.message)
      warn "Pipeline failed during card synthesis: #{synth.error.message}"
      exit 1
    end
    log_event(events_path, stage: "card", message: "synthesize_card:ok", card_id: synth.value.id)

    # Step 5: Screenshots
    captures = {}
    %w[og card simple].each do |variant|
      log_event(events_path, stage: "screenshot", message: "capture:begin", variant: variant)
      shot = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
      if shot.failure?
        log_event(events_path, stage: "screenshot", message: "capture:error", variant: variant, error: shot.error.message, meta: shot.metadata)
        warn "Screenshot failed for #{variant}: #{shot.error.message}"
        exit 1
      end
      captures[variant] = shot.value
      log_event(events_path, stage: "screenshot", message: "capture:ok", variant: variant, output_path: shot.value[:output_path])
    end

    puts "✓ Pipeline completed for #{login}"
    puts "  - Card ID: #{synth.value.id}"
    captures.each { |variant, shot| puts "  - #{variant}: #{shot[:output_path]}" }

    # Final report
    begin
      card = profile&.profile_card
      langs = profile_summary[:languages] || []
      report = {
        generated_at: Time.now.utc.iso8601,
        login: login,
        profile: profile_summary.compact,
        card: card ? { id: card.id, attack: card.attack, defense: card.defense, speed: card.speed, tags: card.tags_array } : nil,
        screenshots: captures,
        images: images_value[:images],
        prompts: prompt_artifacts[:prompts],
        prompt_files: {
          prompts: prompt_artifacts[:prompts_file],
          provider_meta: prompt_artifacts[:provider_meta_file]
        },
        provider_meta: prompt_artifacts[:provider_meta]
      }
      File.write(meta_dir.join("pipeline-report.json"), JSON.pretty_generate(report))
      puts "Saved report: #{meta_dir.join('pipeline-report.json')}"
      puts "Event log:  #{events_path}"
    rescue => e
      warn "Failed to write pipeline report: #{e.message}"
    end
  end

  desc "Enqueue background pipeline job for a login"
  task :pipeline_enqueue, [ :login ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s.downcase
    Profiles::GeneratePipelineJob.perform_later(login)
    puts "Enqueued pipeline job for #{login}"
  end
end
