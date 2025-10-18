module Github
  # Removed: installation discovery no longer used. Require configured installation_id.
  class FindInstallationService < ApplicationService
    def call
      failure(StandardError.new("FindInstallationService removed; configure installation_id"))
    end
  end
end
