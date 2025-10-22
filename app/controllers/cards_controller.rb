class CardsController < ApplicationController
  layout "cards"
  before_action :load_profile
  skip_before_action :load_profile, only: [ :leaderboard_og ]

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

  # --- Social targets (reuse shared templates by dimensions) ---
  # X (Twitter)
  def x_profile_400; render :x_profile_400; end # 400x400 (avatar-only)
  def x_header_1500x500; render :banner; end # 1500x500 reuse banner
  def x_feed_1600x900; render :og; end # 1600x900 close to 1200x630; reuse OG layout

  # Instagram
  def ig_square_1080; render :fb_post_1080; end # 1080x1080 reuse square
  def ig_portrait_1080x1350; render :ig_portrait_1080x1350; end # keep distinct portrait
  def ig_landscape_1080x566; render :og; end # 1080x566 reuse OG layout

  # Facebook
  def fb_post_1080; render :fb_post_1080; end # 1080x1080 square
  def fb_cover_851x315; render :banner; end # 851x315 reuse banner

  # LinkedIn
  def linkedin_profile_400; render :x_profile_400; end # 400x400 reuse avatar-only
  def linkedin_cover_1584x396; render :banner; end # 1584x396 reuse banner

  # YouTube
  def youtube_cover_2560x1440; render :og; end # 2560x1440 reuse OG layout

  # Alias: explicit OG variant name for service consistency
  def og_1200x630; render :og; end # 1200x630

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
