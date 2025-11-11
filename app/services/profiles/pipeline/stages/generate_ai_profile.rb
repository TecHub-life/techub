module Profiles
  module Pipeline
    module Stages
      class GenerateAiProfile < BaseStage
        STAGE_ID = :generate_ai_profile

        def call
          profile = context.profile
          return failure_with_context(StandardError.new("profile_missing_for_ai")) unless profile

          override_mode = context.override(:ai_mode)
          return run_mock(profile) if override_mode.to_s == "mock"

          if FeatureFlags.enabled?(:ai_text)
            run_ai_traits(profile)
          else
            run_heuristic(profile)
          end
        end

        private

        def run_ai_traits(profile)
          providers = Array(ENV["GEMINI_PROVIDER_ORDER"]&.split(",")&.map(&:strip)&.reject(&:blank?))
          providers = Gemini::PROVIDER_ORDER if providers.empty?

          last_error = nil
          last_metadata = nil
          providers.each do |provider|
            trace(:attempt_started, provider: provider)
            result = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: provider)
            if result.success?
              context.card = result.value
              metadata = safe_metadata(result) || {}
              trace(:completed, card_id: result.value&.id, provider: provider, attempts: metadata[:attempts])
              enriched_metadata = metadata.merge(provider: provider).compact
              return success_with_context(result.value, metadata: enriched_metadata)
            end

            last_error = result.error
            last_metadata = safe_metadata(result)
            trace(:attempt_failed, provider: provider, error: result.error&.message)
          end

          # All providers failed — fall back to heuristic synthesis and mark as partial
          trace(:failed, error: last_error&.message || "ai_traits_unavailable_all_providers")

          heur = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
          if heur.success?
            context.card = profile.profile_card
            trace(:heuristic_completed, card_id: context.card&.id, fallback: true)
            metadata = {
              heuristic: true,
              reason: "ai_traits_unavailable",
              fallback: true,
              upstream_error: last_error&.message
            }
            if last_metadata.is_a?(Hash)
              metadata[:prompt] = last_metadata[:prompt] if last_metadata[:prompt]
              metadata[:response_preview] = last_metadata[:response_preview] if last_metadata[:response_preview]
              metadata[:attempts] = last_metadata[:attempts] if last_metadata[:attempts]
              metadata[:provider_attempts] = last_metadata[:provider] if last_metadata[:provider]
            end
            success_with_context(
              context.card,
              metadata: metadata.compact
            )
          else
            trace(:heuristic_failed, error: heur.error&.message)
            failure_with_context(heur.error || StandardError.new("card_synthesis_failed"), metadata: { upstream: safe_metadata(heur) })
          end
        end

        def run_heuristic(profile)
          trace(:heuristic_started)
          result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
          if result.failure?
            trace(:heuristic_failed, error: result.error&.message)
            return failure_with_context(result.error || StandardError.new("card_synthesis_failed"), metadata: { upstream: safe_metadata(result) })
          end

          context.card = profile.profile_card
          trace(:heuristic_completed, card_id: context.card&.id)
          success_with_context(context.card, metadata: { heuristic: true })
        end

        def run_mock(profile)
          trace(:mock_started)
          card = profile.profile_card

          unless card
            heur = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
            if heur.failure?
              trace(:mock_failed, error: heur.error&.message)
              return failure_with_context(heur.error || StandardError.new("card_synthesis_failed"), metadata: { upstream: safe_metadata(heur), mock: true })
            end
            card = profile.profile_card
          end

          context.card = card
          metadata = {
            provider: "mock",
            mock: true,
            prompt: {
              mode: "mock",
              note: "AI generation skipped via pipeline override",
              source_card_id: card&.id
            }
          }
          trace(:mock_completed, card_id: card&.id)
          success_with_context(card, metadata: metadata)
        end
      end
    end
  end
end
