namespace :screenshots do
  desc "Capture card screenshots via Puppeteer. Usage: rake screenshots:capture[login,variant]"
  task :capture, [ :login, :variant, :host, :out ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s
    variant = (args[:variant] || ENV["VARIANT"] || "og").to_s
    host = args[:host] || ENV["APP_HOST"] || (defined?(AppHost) ? AppHost.current : nil)
    out = args[:out]

    result = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host, output_path: out)
    if result.success?
      puts "Saved #{variant} screenshot for #{login}: #{result.value[:output_path]}"
      if (profile = Profile.find_by(login: login))
        rec = ProfileAssets::RecordService.call(
          profile: profile,
          kind: variant,
          local_path: result.value[:output_path],
          public_url: result.value[:public_url],
          mime_type: result.value[:mime_type],
          width: result.value[:width],
          height: result.value[:height],
          provider: "screenshot"
        )
        if rec.success?
          puts "Recorded asset: #{variant} #{rec.value.public_url || rec.value.local_path}"
        else
          warn "Failed to record asset: #{rec.error.message}"
        end
      end
    else
      warn "Screenshot failed: #{result.error.message}"
      warn "Metadata: #{result.metadata.inspect}" if result.metadata
      exit 1
    end
  end

  desc "Enqueue screenshot jobs for all variants (og, card, simple)"
  task :enqueue_all, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s
    host = args[:host] || ENV["APP_HOST"] || (defined?(AppHost) ? AppHost.current : nil)

    %w[og card simple].each do |variant|
      Screenshots::CaptureCardJob.perform_later(login: login, variant: variant, host: host)
      puts "Enqueued #{variant} screenshot job for #{login}"
    end
  end

  desc "Capture all three variants for a login if missing (og, card, simple). Usage: rake screenshots:capture_all[login,host]"
  task :capture_all, [ :login, :host ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s
    host = args[:host] || ENV["APP_HOST"]

    profile = Profile.find_by(login: login)
    gen_dir = Rails.root.join("public", "generated", login)

    variants = %w[og card simple]
    variants.each do |variant|
      already_have = false

      if profile
        asset = profile.profile_assets.find_by(kind: variant)
        already_have ||= asset&.public_url.present? || (asset&.local_path && File.exist?(asset.local_path))
      end

      unless already_have
        # Fallback check for existing files on disk (e.g., previous runs without asset records)
        if Dir.exist?(gen_dir)
          glob = case variant
          when "og" then [ "*.og.*", "og.*", "*og.png", "*og.jpg" ]
          when "card" then [ "card-*.png", "card-*.jpg", "*card.png", "*card.jpg" ]
          else [ "simple-*.png", "simple-*.jpg", "*simple.png", "*simple.jpg" ]
          end
          matched = glob.any? { |g| Dir[gen_dir.join(g).to_s].any? }
          already_have ||= matched
        end
      end

      if already_have
        puts "Skip #{variant}: already present for #{login}"
        next
      end

      puts "Capturing #{variant} for #{login}..."
      res = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
      if res.failure?
        warn "Screenshot failed for #{variant}: #{res.error&.message}"
        warn "Metadata: #{res.metadata.inspect}" if res.metadata
        exit 1
      end

      if profile
        rec = ProfileAssets::RecordService.call(
          profile: profile,
          kind: variant,
          local_path: res.value[:output_path],
          public_url: res.value[:public_url],
          mime_type: res.value[:mime_type],
          width: res.value[:width],
          height: res.value[:height],
          provider: "screenshot"
        )
        if rec.failure?
          warn "Failed to record asset: #{rec.error&.message}"
        end
      end

      puts "Saved #{variant}: #{res.value[:output_path]}"
    end

    puts "Done."
  end
end
