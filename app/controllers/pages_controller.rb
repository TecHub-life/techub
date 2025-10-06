class PagesController < ApplicationController
  def home
    @profile = Profile.find_by(login: "loftwah")

    if @profile.present?
      @profile_summary = @profile.summary
      # Load structured data directly from associations
      @top_repositories = @profile.top_repositories
      @pinned_repositories = @profile.pinned_repositories
      @active_repositories = @profile.active_repositories
      @organizations = @profile.profile_organizations
      @social_accounts = @profile.profile_social_accounts
      @languages = @profile.profile_languages.order(count: :desc)
      @recent_activity = @profile.profile_activity
      @profile_readme = @profile.profile_readme
    else
      result = Profiles::SyncFromGithub.call(login: "loftwah")

      if result.success?
        @profile = result.value
        @profile_summary = @profile.summary
        # Load structured data directly from associations
        @top_repositories = @profile.top_repositories
        @pinned_repositories = @profile.pinned_repositories
        @active_repositories = @profile.active_repositories
        @organizations = @profile.profile_organizations
        @social_accounts = @profile.profile_social_accounts
        @languages = @profile.profile_languages.order(count: :desc)
        @recent_activity = @profile.profile_activity
        @profile_readme = @profile.profile_readme
      else
        Rails.logger.error(
          "Home profile load failed: #{result.error.class} - #{result.error.message}"
        )
        flash.now[:alert] = "Unable to load profile insights right now."
      end
    end
  end

  def directory; end

  def leaderboards; end

  def submit; end

  def faq; end

  def analytics; end

  def docs
    @marketing_overview = File.read(Rails.root.join("docs", "marketing-overview.md")) if File.exist?(Rails.root.join("docs", "marketing-overview.md"))
  end
end
