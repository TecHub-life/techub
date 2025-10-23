module Profiles
  class CleanupTagsJob < ApplicationJob
    queue_as :default

    def perform(limit: 500)
      Directories::CleanupTagsService.call(limit: limit)
    end
  end
end
