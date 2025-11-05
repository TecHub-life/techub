module Profiles
  module Pipeline
    module Stages
      class RecordAvatarAsset < BaseStage
        STAGE_ID = :record_avatar_asset

        KIND = "avatar_github".freeze

        def call
          profile = context.profile
          unless profile
            trace(:failed, error: "profile_missing_for_avatar_asset")
            return failure_with_context(StandardError.new("profile_missing_for_avatar_asset"))
          end

          local_path = context.avatar_local_path.to_s
          public_url = context.avatar_public_url.to_s

          if local_path.blank? && public_url.blank?
            trace(:skipped, reason: "no_avatar_source")
            return success_with_context(nil, metadata: { skipped: true, reason: "no_avatar_source" })
          end

          metadata = context.avatar_upload_metadata || {}
          record = ProfileAssets::RecordService.call(
            profile: profile,
            kind: KIND,
            local_path: local_path.presence || public_url,
            public_url: public_url.presence,
            mime_type: metadata[:content_type],
            provider: "github"
          )

          if record.failure?
            trace(:failed, error: record.error&.message, metadata: safe_metadata(record))
            return failure_with_context(record.error || StandardError.new("avatar_asset_record_failed"), metadata: safe_metadata(record))
          end

          asset = record.value
          trace(:completed, asset_id: asset.id, public_url: asset.public_url)
          success_with_context(asset, metadata: { asset_id: asset.id, public_url: asset.public_url })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end
      end
    end
  end
end
