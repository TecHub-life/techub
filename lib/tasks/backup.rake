namespace :db do
  namespace :backup do
    desc "Create a database backup to object storage (requires BACKUP_BUCKET or DO_SPACES_BUCKET)"
    task create: :environment do
      result = Backups::CreateService.call
      if result.success?
        puts "Uploaded #{result.value[:keys].size} file(s) to bucket: #{result.value[:bucket]}"
        result.value[:keys].each { |k| puts " - #{k}" }
      else
        warn "Backup failed: #{result.error}"
        exit 1
      end
    end

    desc "Prune old backups from S3 per retention env vars"
    task prune: :environment do
      result = Backups::PruneService.call
      if result.success?
        puts "Deleted #{result.value[:deleted]} object(s); kept groups: #{Array(result.value[:kept_groups]).join(", ")}"
      else
        warn "Prune failed: #{result.error}"
        exit 1
      end
    end

    desc "Restore latest or specified backup group to local storage (dev or ALLOW_DB_RESTORE=1). Requires CONFIRM=YES"
    task :restore, [ :group ] => :environment do |_, args|
      group = args[:group].presence || "latest"
      unless ENV["CONFIRM"].to_s.upcase == "YES"
        warn "Set CONFIRM=YES to proceed with restore"
        exit 1
      end
      result = Backups::RestoreService.call(group: group, confirm: ENV["CONFIRM"])
      if result.success?
        puts "Restored group #{result.value[:restored_group]} with files: #{result.value[:files].join(", ")}"
      else
        warn "Restore failed: #{result.error}"
        exit 1
      end
    end

    desc "Doctor: print resolved backup configuration and attempt a non-destructive list"
    task doctor: :environment do
      result = Backups::DoctorService.call
      data = result.metadata
      puts "Backup Doctor"
      puts "  bucket:  #{data[:bucket]}"
      puts "  prefix:  #{data[:prefix]}"
      puts "  region:  #{data[:region]}"
      puts "  endpoint: #{data[:endpoint] || '(default)'}"
      if result.success?
        puts "  can_list: #{data[:can_list]} (sample_count=#{data[:sample_count]})"
        puts "OK"
      else
        warn "  can_list: false"
        warn "  error:    #{result.error.respond_to?(:message) ? result.error.message : result.error}"
        exit 1
      end
    end

    desc "Doctor (write): attempt a write+delete probe under the backup prefix (requires CONFIRM=YES)"
    task doctor_write: :environment do
      unless ENV["CONFIRM"].to_s.upcase == "YES"
        warn "Set CONFIRM=YES to perform write+delete probe"
        exit 1
      end
      result = Backups::WriteProbeService.call
      if result.success?
        puts "Write probe succeeded (wrote+deleted): s3://#{result.value[:bucket]}/#{result.value[:key]}"
      else
        warn "Write probe failed: #{result.error}"
        exit 1
      end
    end
  end
end
    desc "Plan: print JSON for Spaces bucket policy and lifecycle (no network)"
    task plan: :environment do
      creds = (Rails.application.credentials.dig(:do_spaces) rescue {}) || {}
      bucket = ENV["BACKUP_BUCKET"] || creds[:backup_bucket_name] || creds[:bucket_name]
      prefix = ENV["BACKUP_PREFIX"] || creds[:backup_prefix] || "db_backups"
      days = (ENV["BACKUP_RETENTION_DAYS"] || creds[:backup_retention_days] || 14).to_i

      policy = {
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "DenyPublicReadBackupsPrefix",
            Effect: "Deny",
            Principal: "*",
            Action: ["s3:GetObject"],
            Resource: "arn:aws:s3:::%{bucket}/%{prefix}/*" % { bucket: bucket, prefix: prefix },
            Condition: { Bool: { "aws:SecureTransport": "true" } }
          }
        ]
      }

      lifecycle = {
        Rules: [
          {
            ID: "db-backups-expire-#{days}d",
            Filter: { Prefix: "#{prefix}/" },
            Status: "Enabled",
            Expiration: { Days: days }
          }
        ]
      }

      puts "Bucket:  #{bucket}"
      puts "Prefix:  #{prefix}"
      puts "Retention days: #{days}"
      puts "\n# Bucket Policy JSON (deny public read on prefix)\n"
      puts JSON.pretty_generate(policy)
      puts "\n# Lifecycle JSON (expire after #{days} days)\n"
      puts JSON.pretty_generate(lifecycle)
    end
