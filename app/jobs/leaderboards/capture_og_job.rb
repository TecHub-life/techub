module Leaderboards
  class CaptureOgJob < ApplicationJob
    queue_as :screenshots

    def perform(kind: "followers_gain_30d", window: "30d")
      # Ensure data exists
      Leaderboards::ComputeService.call(kind: kind, window: window, as_of: Date.today)
      # Capture the leaderboard OG card
      result = Screenshots::CaptureCardService.call(
        login: "leaderboard", # virtual; route does not use login
        variant: "og",
        host: ENV["APP_HOST"],
        output_path: Rails.root.join("public", "generated", "leaderboard", "og.jpg"),
        wait_ms: 400,
        type: "jpeg",
        quality: 85
      )
      StructuredLogger.info(message: "leaderboard_og_captured", ok: result.success?) if defined?(StructuredLogger)
      result
    end
  end
end
