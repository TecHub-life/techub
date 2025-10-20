namespace :db do
  namespace :backup do
    desc "Create a database backup to S3 (BACKUP_S3_BUCKET required)"
    task create: :environment do
      result = Backups::CreateService.call
      if result.success?
        puts "Uploaded #{result.value[:keys].size} file(s) to s3://#{result.value[:bucket]}"
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
  end
end
