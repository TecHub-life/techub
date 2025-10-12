class User < ApplicationRecord
  encrypts :access_token, deterministic: true

  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true, uniqueness: true

  def github_profile_url
    "https://github.com/#{login}"
  end

  has_many :profile_ownerships, dependent: :destroy
  has_many :profiles, through: :profile_ownerships
end
