class PagesController < ApplicationController
  def home
    @profile = Profile.find_by(github_login: "loftwah")

    if @profile.present?
      @profile_summary = @profile.summary
      @profile_payload = @profile.data.symbolize_keys
    else
      result = Profiles::SyncFromGithub.call(login: "loftwah")

      if result.success?
        @profile = result.value
        @profile_summary = @profile.summary
        @profile_payload = @profile.data.symbolize_keys
      else
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
