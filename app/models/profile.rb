class Profile < ApplicationRecord
  validates :github_login, presence: true, uniqueness: true

  scope :for_login, ->(login) { where(github_login: login.downcase) }

  def top_repositories
    Array(data.presence&.[]("top_repositories"))
  end

  def languages
    Array(data.presence&.[]("languages"))
  end
end
