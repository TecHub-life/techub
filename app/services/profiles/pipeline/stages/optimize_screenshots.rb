module Profiles
  module Pipeline
    module Stages
      class OptimizeScreenshots < BaseStage
        STAGE_ID = :optimize_card_images

        def call
          captures = context.captures || {}
          if captures.empty?
            trace(:skipped)
            return success_with_context({}, metadata: { skipped: true, reason: "no_captures" })
          end

          trace(:started, count: captures.size)
          optimizations = {}
          captures.each do |variant, data|
            path = data[:local_path]
            unless path && File.exist?(path)
              trace(:variant_skipped, variant: variant, reason: "missing_file")
              next
            end

            size_before = safe_file_size(path)
            trace(:variant_started, variant: variant, size_before: size_before)

            Images::OptimizeJob.perform_now(
              path: path,
              login: context.profile&.login || login,
              kind: variant,
              min_bytes_for_bg: threshold,
              upload: upload_after_optimization?
            )

            size_after = safe_file_size(path)
            optimizations[variant] = {
              path: path,
              size_before: size_before,
              size_after: size_after,
              changed: size_before && size_after ? size_after != size_before : false
            }
            trace(:variant_completed, variant: variant, metrics: optimizations[variant])
          end

          context.optimizations = optimizations
          trace(:completed, optimized: optimizations.keys)
          success_with_context(
            optimizations,
            metadata: {
              optimized: optimizations.length,
              variants: optimizations.keys,
              assets: optimizations
            }
          )
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def log_service(status, error: nil, metadata: {})
          summary = metadata.is_a?(Hash) ? metadata.slice(:optimized, :variants, :skipped, :reason) : {}
          super(status, error: error, metadata: summary)
        end

        def threshold
          (options[:threshold] || ENV["IMAGE_OPT_BG_THRESHOLD"] || 300_000).to_i
        end

        def upload_after_optimization?
          options.key?(:upload) ? !!options[:upload] : Rails.env.production?
        end

        def safe_file_size(path)
          File.size(path)
        rescue StandardError
          nil
        end
      end
    end
  end
end
