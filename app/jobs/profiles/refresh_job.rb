module Profiles
  class RefreshJob < ApplicationJob
    queue_as :default

    def perform(login)
      Profiles::SyncFromGithub.call(login: login)
    end
  end
end
