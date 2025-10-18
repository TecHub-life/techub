module Github
  # Removed: logic inlined into Github::AppClientService.
  class InstallationTokenService < ApplicationService
    def call
      failure(StandardError.new("InstallationTokenService removed; use Github::AppClientService"))
    end
  end
end
