module Profiles
  module Pipeline
    module Stages
      class CaptureScreenshots < BaseStage
        STAGE_ID = :capture_card_screenshots

        def call
          profile = context.profile
          return failure_with_context(StandardError.new("profile_missing_for_screenshots")) unless profile

          variants = Array(options[:variants]).presence || []
          trace(:started, variants: variants, host: host)

          captures = {}
        variants.each do |variant|
          trace(:variant_started, variant: variant)
          asset = Screenshots::CaptureCardJob.perform_now(
            login: profile.login,
            variant: variant,
            host: host,
            optimize: false
          )
          unless asset && asset.respond_to?(:id)
            trace(:variant_failed, variant: variant, error: "asset_not_recorded")
            return failure_with_context(StandardError.new("screenshot_failed"), metadata: { variant: variant })
          end
          captures[variant] = snapshot_asset(asset)
          trace(:variant_completed, variant: variant, asset: captures[variant])
        end

          context.captures = captures
          trace(:completed, count: captures.length)
          success_with_context(captures, metadata: { captures: captures.length })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def snapshot_asset(asset)
          {
            id: asset.id,
            kind: asset.kind,
            local_path: asset.local_path,
            public_url: asset.public_url,
            width: asset.width,
            height: asset.height,
            mime_type: asset.mime_type,
            created_at: asset.created_at,
            updated_at: asset.updated_at
          }
        end
      end
    end
  end
end
