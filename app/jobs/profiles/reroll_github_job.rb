module Profiles
  class RerollGithubJob < ApplicationJob
    queue_as :default

    def perform(login:)
      ctx = Profiles::Pipeline::Context.new(login: login, host: nil)
      fetch = Profiles::Pipeline::Stages::FetchGithubProfile.call(context: ctx)
      raise(fetch.error || StandardError.new("fetch_failed")) if fetch.failure?
      Profiles::Pipeline::Stages::DownloadAvatar.call(context: ctx)
      persist = Profiles::Pipeline::Stages::PersistGithubProfile.call(context: ctx)
      raise(persist.error || StandardError.new("persist_failed")) if persist.failure?
    end
  end
end
