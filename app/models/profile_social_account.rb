class ProfileSocialAccount < ApplicationRecord
  belongs_to :profile

  validates :provider, presence: true

  scope :by_provider, ->(provider) { where(provider: provider.upcase) }

  def display_name
    self.display_name.presence || extract_username_from_url
  end

  def username
    extract_username_from_url
  end

  private

  def extract_username_from_url
    return nil unless url.present?

    case provider.upcase
    when "TWITTER", "X"
      url.match(%r{twitter\.com/([^/?]+)})&.[](1) || url.match(%r{x\.com/([^/?]+)})&.[](1)
    when "BLUESKY"
      url.match(%r{bsky\.app/profile/([^/?]+)})&.[](1)
    when "LINKEDIN"
      url.match(%r{linkedin\.com/in/([^/?]+)})&.[](1)
    when "FACEBOOK"
      url.match(%r{facebook\.com/([^/?]+)})&.[](1)
    when "INSTAGRAM"
      url.match(%r{instagram\.com/([^/?]+)})&.[](1)
    when "YOUTUBE"
      url.match(%r{youtube\.com/(?:c/|channel/|user/)?([^/?]+)})&.[](1)
    when "REDDIT"
      url.match(%r{reddit\.com/u(?:ser)?/([^/?]+)})&.[](1)
    when "TWITCH"
      url.match(%r{twitch\.tv/([^/?]+)})&.[](1)
    when "MASTODON"
      url.match(%r{([^/]+)\.social/([^/?]+)})&.[](2) || url.match(%r{mastodon\.social/([^/?]+)})&.[](1)
    when "NPM"
      url.match(%r{npmjs\.com/~([^/?]+)})&.[](1)
    else
      nil
    end
  end
end
