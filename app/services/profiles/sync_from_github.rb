module Profiles
  class SyncFromGithub < ApplicationService
    def initialize(login:)
      @login = login.to_s.downcase
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      context = Pipeline::Context.new(login: login, host: nil)

      fetch = Pipeline::Stages::FetchGithubProfile.call(context: context)
      return fetch if fetch.failure?

      download = Pipeline::Stages::DownloadAvatar.call(context: context)
      return download if download.failure?

      persist = Pipeline::Stages::PersistGithubProfile.call(context: context)
      return persist if persist.failure?

      success(context.profile, metadata: build_metadata(context, download, started))
    end

    private

    attr_reader :login

    def build_metadata(context, download_result, started_at)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      {
        run_id: context.run_id,
        host: context.host,
        duration_ms: duration_ms,
        avatar_download: download_result.respond_to?(:metadata) ? download_result.metadata : nil,
        trace: context.trace_entries
      }.compact
    end
  end
end
