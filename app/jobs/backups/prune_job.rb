module Backups
  class PruneJob < ApplicationJob
    queue_as :default

    def perform
      Backups::PruneService.call
    end
  end
end
