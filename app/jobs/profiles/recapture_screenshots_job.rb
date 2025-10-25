module Profiles
  class RecaptureScreenshotsJob < ApplicationJob
    queue_as :screenshots

    def perform(login:, variants: nil)
      profile = Profile.for_login(login).first
      return unless profile
      kinds = Array(variants).presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS
      kinds.each do |variant|
        Screenshots::CaptureCardJob.perform_later(login: profile.login, variant: variant, optimize: true)
      end
    end
  end
end
