module Profiles
  class CleanupTagsJob < ApplicationJob
    queue_as :default

    def perform(limit: 500)
      Profiles::CleanupTagsService.call(limit: limit)
    end
  end
end
