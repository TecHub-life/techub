module Profiles
  module Pipeline
    module Stages
      class GenerateAiProfile < BaseStage
        STAGE_ID = :generate_ai_profile

        def call
          profile = context.profile
          return failure_with_context(StandardError.new("profile_missing_for_ai")) unless profile

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
          providers.each do |provider|
            trace(:attempt_started, provider: provider)
            result = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: provider)
            if result.success?
              context.card = result.value
              trace(:completed, card_id: result.value&.id, provider: provider, attempts: safe_metadata(result)&.[](:attempts))
              return success_with_context(result.value, metadata: { attempts: safe_metadata(result)&.[](:attempts), provider: provider })
            end

            last_error = result.error
            trace(:attempt_failed, provider: provider, error: result.error&.message)
          end

          # All providers failed — fall back to heuristic synthesis and mark as partial
          trace(:failed, error: last_error&.message || "ai_traits_unavailable_all_providers")

          heur = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
          if heur.success?
            context.card = profile.profile_card
            trace(:heuristic_completed, card_id: context.card&.id, fallback: true)
            success_with_context(context.card, metadata: { heuristic: true, partial: true, reason: "ai_traits_unavailable" })
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
      end
    end
  end
end
