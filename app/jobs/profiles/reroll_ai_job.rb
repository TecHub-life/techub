module Profiles
  class RerollAiJob < ApplicationJob
    queue_as :default

    def perform(login:)
      profile = Profile.for_login(login).first
      return unless profile
      if profile.unlisted?
        StructuredLogger.info(message: "reroll_skipped", service: self.class.name, login: login, reason: "unlisted")
        return
      end
      if FeatureFlags.enabled?(:ai_text)
        result = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: "ai_studio")
        raise(result.error || StandardError.new("ai_traits_failed")) if result.failure?
      else
        result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
        raise(result.error || StandardError.new("card_synthesis_failed")) if result.failure?
      end
    end
  end
end
