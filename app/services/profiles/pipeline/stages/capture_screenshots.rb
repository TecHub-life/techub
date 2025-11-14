module Profiles
  module Pipeline
    module Stages
      class CaptureScreenshots < BaseStage
        STAGE_ID = :capture_card_screenshots

        def call
          profile = context.profile
          return failure_with_context(StandardError.new("profile_missing_for_screenshots")) unless profile

          screenshots_mode = context.override(:screenshots_mode) || context.override(:screenshots)
          if screenshots_mode.to_s == "skip"
            trace(:skipped_via_override, reason: "screenshots_override_skip")
            context.captures = {}
            return success_with_context({}, metadata: { skipped: true, reason: "screenshots_override_skip" })
          end

          override_variants = Array(context.override(:screenshot_variants))
                              .map { |variant| variant.to_s.strip }
                              .reject(&:blank?)
          variants = override_variants.presence || Array(options[:variants]).presence || []
          if variants.empty?
            trace(:skipped, reason: "no_variants")
            context.captures = {}
            return success_with_context({}, metadata: { skipped: true, reason: "no_variants" })
          end
          trace(:started, variants: variants, host: host)

          captures = {}
          failures = []
          variants.each do |variant|
            trace(:variant_started, variant: variant)
            begin
              asset = Screenshots::CaptureCardJob.perform_now(
                login: profile.login,
                variant: variant,
                host: host,
                optimize: false
              )
              if asset && asset.respond_to?(:id)
                captures[variant] = snapshot_asset(asset)
                trace(:variant_completed, variant: variant, asset: captures[variant])
              else
                trace(:variant_failed, variant: variant, error: "asset_not_recorded")
                failures << { variant: variant, error: "asset_not_recorded" }
              end
            rescue StandardError => e
              trace(:variant_exception, variant: variant, error: e.message)
              failures << { variant: variant, error: e.message }
            end
          end

          context.captures = captures
          meta = { captures: captures.length, variants: captures.keys, assets: captures, failures: failures }

          if failures.any?
            if captures.any?
              trace(:completed_degraded, **meta)
              return degraded_with_context(captures, metadata: meta)
            else
              trace(:failed, **meta)
              return failure_with_context(StandardError.new("screenshot_failed"), metadata: meta)
            end
          end

          trace(:completed, count: captures.length)
          success_with_context(captures, metadata: meta)
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def log_service(status, error: nil, metadata: {})
          summary = metadata.is_a?(Hash) ? metadata.slice(:captures, :variants, :skipped, :reason) : {}
          super(status, error: error, metadata: summary)
        end

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
