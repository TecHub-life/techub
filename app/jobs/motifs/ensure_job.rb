module Motifs
  class EnsureJob < ApplicationJob
    queue_as :default

    def perform(theme: "core")
      Motifs::GenerateLibraryService.call(theme: theme, ensure_only: true)
    end
  end
end
