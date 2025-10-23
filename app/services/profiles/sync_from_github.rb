module Profiles
  class SyncFromGithub < ApplicationService
    def initialize(login:)
      @login = login.to_s.downcase
    end

    def call
      context = Pipeline::Context.new(login: login, host: nil)

      fetch = Pipeline::Stages::FetchGithubProfile.call(context: context)
      return fetch if fetch.failure?

      Pipeline::Stages::DownloadAvatar.call(context: context)

      persist = Pipeline::Stages::PersistGithubProfile.call(context: context)
      return persist if persist.failure?

      success(context.profile)
    end

    private

    attr_reader :login
  end
end
