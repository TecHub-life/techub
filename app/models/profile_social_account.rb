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
    else
      nil
    end
  end
end
