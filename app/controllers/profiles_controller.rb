class ProfilesController < ApplicationController
  def show
    username = params[:username].downcase

    @profile = Profile.find_by(github_login: username)

    if @profile.present?
      # Use cached data if it's recent (less than 1 hour old)
      if @profile.last_synced_at && @profile.last_synced_at > 1.hour.ago
        load_profile_data
      else
        # Refresh if stale
        refresh_and_load_profile(username)
      end
    else
      # New profile - fetch from GitHub
      refresh_and_load_profile(username)
    end

    # Render the home template (same UI, different data)
    render "pages/home"
  rescue => e
    Rails.logger.error("Profile load failed for #{username}: #{e.class} - #{e.message}")
    flash.now[:alert] = "Unable to load profile for @#{username}. Please check the username and try again."
    render "pages/home"
  end

  private

  def load_profile_data
    @profile_summary = @profile.summary
    @profile_payload = @profile.data.deep_symbolize_keys
  end

  def refresh_and_load_profile(username)
    result = Profiles::SyncFromGithub.call(login: username)

    if result.success?
      @profile = result.value
      load_profile_data
    else
      Rails.logger.error(
        "Profile sync failed for #{username}: #{result.error.class} - #{result.error.message}"
      )
      flash.now[:alert] = if result.error.is_a?(Octokit::NotFound)
        "GitHub user @#{username} not found."
      else
        "Unable to load profile for @#{username} right now. Please try again later."
      end
    end
  end
end
