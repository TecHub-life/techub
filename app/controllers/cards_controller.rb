class CardsController < ApplicationController
  layout "cards"
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

  # 1500x500 — banner (3:1)
  def banner
    render :banner
  end

  # Leaderboard OG card (1200x630)
  def leaderboard_og
    render :leaderboard_og
  end

  private

  def load_profile
    login = params[:login].to_s.downcase
    @profile = Profile.for_login(login).first
    render plain: "Not found", status: :not_found unless @profile
  end
end
