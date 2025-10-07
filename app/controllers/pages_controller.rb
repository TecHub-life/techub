class PagesController < ApplicationController
  def home
    # Landing page - no profile data needed
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
