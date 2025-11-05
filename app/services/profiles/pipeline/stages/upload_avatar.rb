module Profiles
  module Pipeline
    module Stages
      class UploadAvatar < BaseStage
        STAGE_ID = :upload_github_avatar

        def call
          local_path = context.avatar_local_path.to_s
          if local_path.blank?
            trace(:skipped, reason: "no_local_avatar")
            return success_with_context(nil, metadata: { skipped: true, reason: "no_local_avatar" })
          end

          if Storage::ServiceProfile.disk_service?
            public_path = context.avatar_relative_path.presence || relative_path_for(local_path)
            context.avatar_public_url = public_path
            context.avatar_upload_metadata = {
              service: Storage::ServiceProfile.service_name,
              disk: true,
              local_path: local_path
            }.compact
            trace(:skipped_disk_service, public_path: public_path, service: Storage::ServiceProfile.service_name)
            return success_with_context(
              public_path,
              metadata: {
                disk_service: true,
                service: Storage::ServiceProfile.service_name,
                public_path: public_path
              }.compact
            )
          end

          unless File.exist?(local_path)
            trace(:failed, error: "avatar_file_missing", path: local_path)
            return failure_with_context(StandardError.new("avatar_file_missing"), metadata: { path: local_path })
          end

          upload = Storage::ActiveStorageUploadService.call(
            path: local_path,
            content_type: detect_mime(local_path),
            filename: File.basename(local_path)
          )

          if upload.failure?
            trace(:upload_failed, error: upload.error&.message, metadata: safe_metadata(upload))
            StructuredLogger.warn(
              message: "avatar_upload_failed",
              login: login,
              error: upload.error&.message,
              path: local_path
            ) if defined?(StructuredLogger)
            return degraded_with_context(
              nil,
              metadata: { reason: "avatar_upload_failed", upstream: safe_metadata(upload) }
            )
          end

          value = upload.value || {}
          public_url = value[:public_url]
          context.avatar_public_url = public_url
          context.avatar_upload_metadata = value.merge(content_type: detect_mime(local_path))
          trace(:completed, public_url: public_url, key: value[:key])
          success_with_context(public_url, metadata: { public_url: public_url, storage_key: value[:key] })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e, metadata: { path: context.avatar_local_path })
        end

        private

        def detect_mime(path)
          Marcel::MimeType.for(Pathname.new(path), fallback: "image/png")
        rescue StandardError
          "image/png"
        end

        def relative_path_for(path)
          absolute = Pathname.new(path)
          public_dir = Rails.root.join("public")
          if absolute.to_s.start_with?(public_dir.to_s)
            "/" + absolute.relative_path_from(public_dir).to_s
          else
            absolute.to_s
          end
        rescue StandardError
          path
        end
      end
    end
  end
end
