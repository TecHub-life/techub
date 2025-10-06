class ProfileRepository < ApplicationRecord
  belongs_to :profile
  has_many :repository_topics, dependent: :destroy

  validates :name, presence: true
  validates :repository_type, inclusion: { in: %w[top pinned active] }

  scope :by_type, ->(type) { where(repository_type: type) }
  scope :by_language, ->(language) { where(language: language) }
  scope :most_starred, -> { order(stargazers_count: :desc) }
  scope :recently_updated, -> { order(github_updated_at: :desc) }

  def topics_list
    repository_topics.pluck(:name)
  end

  def has_topics?
    repository_topics.exists?
  end

  def github_url
    html_url || "https://github.com/#{full_name || profile.login}/#{name}"
  end
end
