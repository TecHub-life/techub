module Leaderboards
  class RebuildJob < ApplicationJob
    queue_as :default

    def perform
      kinds = Leaderboard::KINDS
      windows = Leaderboard::WINDOWS
      as_of = Date.today

      kinds.each do |kind|
        windows.each do |window|
          result = Leaderboards::ComputeService.call(kind: kind, window: window, as_of: as_of)
          StructuredLogger.info(message: "leaderboard_rebuild", kind: kind, window: window, ok: result.success?) if defined?(StructuredLogger)
        end
      end
    end
  end
end
