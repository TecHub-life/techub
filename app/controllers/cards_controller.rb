class CardsController < ApplicationController
  before_action :load_profile

  # 1200x630 — OpenGraph recommended
  def og
    render :og
  end

  # 1280x720 — TecHub card preview (16:9)
  def card
    render :card
  end

  # 1280x720 — simplified variant
  def simple
    render :simple
  end

  private

  def load_profile
    login = params[:login].to_s.downcase
    @profile = Profile.for_login(login).first
    unless @profile
      result = Profiles::SyncFromGithub.call(login: login)
      @profile = result.value if result.success?
    end
    render plain: "Not found", status: :not_found unless @profile
  end
end
