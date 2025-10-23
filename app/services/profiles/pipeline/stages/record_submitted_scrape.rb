module Profiles
  module Pipeline
    module Stages
      class RecordSubmittedScrape < BaseStage
        STAGE_ID = :record_submitted_scrape

        def call
          profile = context.profile
          return success_with_context(nil, metadata: { skipped: true }) unless profile

          url = profile.respond_to?(:submitted_scrape_url) ? profile.submitted_scrape_url.to_s : ""
          if url.blank?
            trace(:skipped)
            return success_with_context(nil, metadata: { skipped: true })
          end

          trace(:started, url: url)
          result = Profiles::RecordSubmittedScrapeService.call(profile: profile, url: url)
          if result.failure?
            trace(:failed, error: result.error&.message)
            StructuredLogger.warn(
              message: "submitted_scrape_failed",
              login: login,
              error: result.error&.message
            ) if defined?(StructuredLogger)
            return failure_with_context(result.error || StandardError.new("submitted_scrape_failed"), metadata: { url: url })
          end

          context.scrape = result.value
          trace(:completed, scrape_id: result.value&.id)
          success_with_context(result.value, metadata: { scrape_id: result.value&.id })
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end
      end
    end
  end
end
