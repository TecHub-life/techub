namespace :screenshots do
  desc "Capture card screenshots via Puppeteer. Usage: rake screenshots:capture[login,variant]"
  task :capture, [ :login, :variant, :host, :out ] => :environment do |_, args|
    login = (args[:login] || ENV["LOGIN"] || "loftwah").to_s
    variant = (args[:variant] || ENV["VARIANT"] || "og").to_s
    host = args[:host] || ENV["APP_HOST"]
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
    host = args[:host] || ENV["APP_HOST"]

    %w[og card simple].each do |variant|
      Screenshots::CaptureCardJob.perform_later(login: login, variant: variant, host: host)
      puts "Enqueued #{variant} screenshot job for #{login}"
    end
  end
end
