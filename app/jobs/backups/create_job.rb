module Backups
  class CreateJob < ApplicationJob
    queue_as :default

    def perform
      Backups::CreateService.call
    end
  end
end
